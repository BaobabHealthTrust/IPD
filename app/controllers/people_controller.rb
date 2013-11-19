class PeopleController < GenericPeopleController

  def demographics
    # Search by the demographics that were passed in and then return demographics
    people = PatientService.find_person_by_demographics(params)
    result = people.empty? ? {} : PatientService.demographics(people.first)
    render :text => result.to_json
  end
  
  def confirm
    session_date = session[:datetime] || Date.today
    if request.post?
      redirect_to search_complete_url(params[:found_person_id], params[:relation]) and return
    end
    @found_person_id = params[:found_person_id] 
    @relation = params[:relation]
    @person = Person.find(@found_person_id) rescue nil
    @arv_number = PatientService.get_patient_identifier(@person, 'ARV Number')
	  @patient_bean = PatientService.get_patient(@person)
    program_id = Program.find_by_name('IPD PROGRAM').id
    @patient = @person.patient
    @ipd_program_id = @patient.patient_programs.current.local.select{|p| p.program_id == program_id }.last.patient_program_id rescue nil
    @task = main_next_task(Location.current_health_center, @person.patient)
    render :layout => false
  end

  def search
    found_person = nil
    if params[:identifier]
      local_results = PatientService.search_by_identifier(params[:identifier])
      if local_results.length > 1
        redirect_to :action => 'duplicates' ,:search_params => params
        return
      elsif local_results.length == 1
        if create_from_dde_server
          dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
          dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""
          dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""
          uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json"
          uri += "?value=#{params[:identifier]}"
          output = RestClient.get(uri)
          p = JSON.parse(output)
          if p.count > 1
            redirect_to :action => 'duplicates' ,:search_params => params
            return
          end
        end
        found_person = local_results.first
      else
        # TODO - figure out how to write a test for this
        # This is sloppy - creating something as the result of a GET
        if create_from_remote
          found_person_data = PatientService.find_remote_person_by_identifier(params[:identifier])
          found_person = PatientService.create_from_form(found_person_data['person']) unless found_person_data.blank?
        end
      end
      if found_person
        if params[:identifier].length != 6 and create_from_dde_server
          patient = DDEService::Patient.new(found_person.patient)
          national_id_replaced = patient.check_old_national_id(params[:identifier])
          if national_id_replaced.to_s != "true" and national_id_replaced.to_s !="false"
            redirect_to :action => 'remote_duplicates' ,:search_params => params
            return
          end
        end

        if params[:relation]
          redirect_to search_complete_url(found_person.id, params[:relation]) and return
        elsif national_id_replaced.to_s == "true"
          DDEService.create_footprint(PatientService.get_patient(found_person).national_id, "ADT")
          print_and_redirect("/patients/national_id_label?patient_id=#{found_person.id}", next_task(found_person.patient)) and return
          redirect_to :controller =>'people',:action => 'confirm',
            :found_person_id => found_person.id, :relation => params[:relation] and return
        else
          #creating patient's footprint so that we can track them later when they visit other sites
          DDEService.create_footprint(PatientService.get_patient(found_person).national_id, "ADT")
          redirect_to :controller =>'people',:action => 'confirm',
            :found_person_id => found_person.id, :relation => params[:relation] and return
        end
      end
    end

    @relation = params[:relation]
    @people = PatientService.person_search(params)
    @search_results = {}
    @patients = []

    (PatientService.search_from_remote(params) || []).each do |data|
      national_id = data["person"]["data"]["patient"]["identifiers"]["National id"] rescue nil
      national_id = data["person"]["value"] if national_id.blank? rescue nil
      national_id = data["npid"]["value"] if national_id.blank? rescue nil
      national_id = data["person"]["data"]["patient"]["identifiers"]["old_identification_number"] if national_id.blank? rescue nil

      next if national_id.blank?
      results = PersonSearch.new(national_id)
      results.national_id = national_id
      results.current_residence =data["person"]["data"]["addresses"]["city_village"]
      results.person_id = 0
      results.home_district = data["person"]["data"]["addresses"]["address2"]
      results.traditional_authority =  data["person"]["data"]["addresses"]["county_district"]
      results.name = data["person"]["data"]["names"]["given_name"] + " " + data["person"]["data"]["names"]["family_name"]
      gender = data["person"]["data"]["gender"]
      results.occupation = data["person"]["data"]["occupation"]
      results.sex = (gender == 'M' ? 'Male' : 'Female')
      results.birthdate_estimated = (data["person"]["data"]["birthdate_estimated"]).to_i
      results.birth_date = birthdate_formatted((data["person"]["data"]["birthdate"]).to_date , results.birthdate_estimated)
      results.birthdate = (data["person"]["data"]["birthdate"]).to_date
      results.age = cul_age(results.birthdate.to_date , results.birthdate_estimated)
      @search_results[results.national_id] = results
    end if create_from_dde_server

    (@people || []).each do | person |
      patient = PatientService.get_patient(person) rescue nil
      next if patient.blank?
      results = PersonSearch.new(patient.national_id || patient.patient_id)
      results.national_id = patient.national_id
      results.birth_date = patient.birth_date
      results.current_residence = patient.current_residence
      results.guardian = patient.guardian
      results.person_id = patient.person_id
      results.home_district = patient.home_district
      results.current_district = patient.current_district
      results.traditional_authority = patient.traditional_authority
      results.mothers_surname = patient.mothers_surname
      results.dead = patient.dead
      results.arv_number = patient.arv_number
      results.eid_number = patient.eid_number
      results.pre_art_number = patient.pre_art_number
      results.name = patient.name
      results.sex = patient.sex
      results.age = patient.age
      @search_results.delete_if{|x,y| x == results.national_id }
      @patients << results
    end

		(@search_results || {}).each do | npid , data |
			@patients << data
		end
	end

  def search_from_dde
		found_person = PatientService.person_search_from_dde(params)
    if found_person
      if params[:relation]
        redirect_to search_complete_url(found_person.id, params[:relation]) and return
      else
        redirect_to :action => 'confirm',:controller =>'people',
          :found_person_id => found_person.id,
          :relation => params[:relation] and return
      end
    else
      redirect_to :action => 'search' and return
    end
  end

  def duplicates
    @duplicates = []
    people = PatientService.person_search(params[:search_params])
    people.each do |person|
      @duplicates << PatientService.get_patient(person)
    end unless people == "found duplicate identifiers"

    if create_from_dde_server
      @remote_duplicates = []
      PatientService.search_from_dde_by_identifier(params[:search_params][:identifier]).each do |person|
        @remote_duplicates << PatientService.get_dde_person(person)
      end
    end

    @selected_identifier = params[:search_params][:identifier]
    @logo = CoreService.get_global_property_value("logo")
    render :layout => 'menu'
  end

  def reassign_dde_national_id
    person = DDEService.reassign_dde_identification(params[:dde_person_id],params[:local_person_id])
    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end

  def remote_duplicates
    if params[:patient_id]
      @primary_patient = PatientService.get_patient(Person.find(params[:patient_id]))
    else
      @primary_patient = nil
    end

    @dde_duplicates = []
    if create_from_dde_server
      PatientService.search_from_dde_by_identifier(params[:identifier]).each do |person|
        @dde_duplicates << PatientService.get_dde_person(person)
      end
    end

    if @primary_patient.blank? and @dde_duplicates.blank?
      redirect_to :action => 'search',:identifier => params[:identifier] and return
    end
    render :layout => 'menu'
  end

  def reassign_national_identifier
    patient = Patient.find(params[:person_id])
    if create_from_dde_server
      passed_params = PatientService.demographics(patient.person)
      new_npid = PatientService.create_from_dde_server_only(passed_params)
      npid = PatientIdentifier.new()
      npid.patient_id = patient.id
      npid.identifier_type = PatientIdentifierType.find_by_name('National ID')
      npid.identifier = new_npid
      npid.save
    else
      PatientIdentifierType.find_by_name('National ID').next_identifier({:patient => patient})
    end
    npid = PatientIdentifier.find(:first,
           :conditions => ["patient_id = ? AND identifier = ?
           AND voided = 0", patient.id,params[:identifier]])
    npid.voided = 1
    npid.void_reason = "Given another national ID"
    npid.date_voided = Time.now()
    npid.voided_by = current_user.id
    npid.save

    print_and_redirect("/patients/national_id_label?patient_id=#{patient.id}", next_task(patient))
  end

  def create_person_from_dde
    person = DDEService.get_remote_person(params[:remote_person_id])

    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end


  protected

  def cul_age(birthdate , birthdate_estimated , date_created = Date.today, today = Date.today)
                                                                                
    # This code which better accounts for leap years                            
    patient_age = (today.year - birthdate.year) + ((today.month - birthdate.month) + ((today.day - birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)
                                                                                
    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date = birthdate                                                      
    estimate = birthdate_estimated == 1                                         
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && date_created.year == today.year) ? 1 : 0
  end                                                                           
                                                                                
  def birthdate_formatted(birthdate,birthdate_estimated)                        
    if birthdate_estimated == 1                                                 
      if birthdate.day == 1 and birthdate.month == 7                            
        birthdate.strftime("??/???/%Y")                                         
      elsif birthdate.day == 15                                                 
        birthdate.strftime("??/%b/%Y")                                          
      elsif birthdate.day == 1 and birthdate.month == 1                         
        birthdate.strftime("??/???/%Y")                                         
      end                                                                       
    else                                                                        
      birthdate.strftime("%d/%b/%Y")                                            
    end                                                                         
  end
end
 

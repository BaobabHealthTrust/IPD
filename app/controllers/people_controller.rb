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
      params[:identifier] = params[:identifier].strip
			local_results = DDE2Service.search_all_by_identifier(params[:identifier])
			if local_results.length > 1
				redirect_to :action => 'duplicates' ,:search_params => params
        return
			elsif local_results.length <= 1

				if create_from_dde_server
          p = DDE2Service.search_by_identifier(params[:identifier])

          if p.count > 1
						redirect_to :action => 'duplicates' ,:search_params => params
						return
          elsif (p.blank? || p.count == 0) && local_results.count == 1
            patient_bean = PatientService.get_patient(local_results.first)
            DDE2Service.push_to_dde2(patient_bean)
          elsif p.count == 1 and local_results.count == 1
            patient_bean = PatientService.get_patient(local_results.first)
            new_id = p.first["npid"] rescue nil
            if new_id.present? && new_id.length == 6 && new_id != patient_bean.national_id
              DDE2Service.update_national_id(patient_bean, new_id)
            end    
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

      found_person = local_results.first if !found_person.blank?

      if found_person
        if create_from_dde_server
          patient = found_person.patient
          old_npid = params[:identifier].gsub(/\-/, '').upcase.strip
          patient_bean = PatientService.get_patient(found_person)
          new_npid = patient_bean.national_id.gsub(/\-/, '').upcase.strip

          if old_npid != new_npid
            print_and_redirect("/patients/national_id_label?patient_id=#{patient.id}", next_task(patient)) and return
          end

        end
				if params[:relation]
					redirect_to search_complete_url(found_person.id, params[:relation]) and return
				else
          
          redirect_to next_task(found_person.patient) and return
          # redirect_to :action => 'confirm', :found_person_id => found_person.id, :relation => params[:relation] and return
				end
      end

		end

		@relation = params[:relation]
    @people = []
		@people = PatientService.person_search(params) if !params[:given_name].blank?
    @search_results = {}
    @patients = []

    remote_results = []
    if create_from_dde_server
      remote_results = DDE2Service.search_from_dde2(params) if !params[:given_name].blank?
    end

	  (remote_results || []).each do |data|
      national_id = data["npid"] rescue nil
      next if national_id.blank?
      results = PersonSearch.new(national_id)
      results.national_id = national_id

      results.current_residence = data["addresses"]["current_village"]
      results.person_id = 0
      results.home_district = data["addresses"]["home_district"]
      results.traditional_authority =  data["addresses"]["home_ta"]
      results.name = data["names"]["given_name"] + " " + data["names"]["family_name"]
      results.occupation = data["occupation"]
      results.sex = data["gender"].match('F') ? 'Female' : 'Male'
      results.birthdate_estimated = data["birthdate_estimated"]
      results.birth_date = ((data["birthdate"]).to_date.strftime("%d/%b/%Y") rescue data["birthdate"])
      results.age = cul_age(results.birth_date.to_date , results.birthdate_estimated)
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


  def conflicts

    response = DDE2Service.create_from_dde2(params[:local_data]) if params[:local_data].present?

    if params[:identifier].present?
      response = DDE2Service.search_by_identifier(params['identifier'])
    end

    @return_path = response[:return_path] rescue nil
    @local_duplicates = ([params[:local_data]] rescue []).compact
    @remote_duplicates = response['data'] rescue []

    (@local_duplicates || []).each do |r|
      r['return_path'] = response['return_path']
    end

    d = params[:local_data]
    if d.blank?
      @local_found = PatientIdentifier.find_by_sql("SELECT *, patient_id AS person_id FROM patient_identifier
                      WHERE identifier = '#{params[:identifier]}' AND identifier_type = 3 AND voided = 0")

    else
    gender = d['gender'].match('F') ? 'F' : 'M'
    @local_found = Person.find_by_sql("SELECT * from person p
                                   INNER JOIN person_name pn on pn.person_id = p.person_id AND pn.voided != 1
                                   INNER JOIN person_address pd ON p.person_id = pd.person_id AND pd.voided != 1
                                   WHERE p.voided != 1 AND pn.given_name = '#{d['given_name']}' AND pn.family_name = '#{d['family_name']}'
                                    AND pd.address2 = '#{d['home_district']}'
                                    AND p.gender = '#{gender}' AND p.birthdate = '#{d['birthdate'].to_date.strftime('%Y-%m-%d')}'

                                      ")

    end

    (@local_found || []).each do |p|
      p = Person.find(p.person_id) rescue next
      patient_bean = PatientService.get_patient(p)

      @local_duplicates << {
          "family_name"=> patient_bean.last_name,
          "given_name"=> patient_bean.first_name,
          "npid" => patient_bean.national_id,
          "patient_id" => patient_bean.patient_id,
          "gender"=> patient_bean.sex,
          "attributes"=> {
              "occupation"=> (patient_bean.occupation rescue ""),
              "cell_phone_number"=> (patient_bean.cell_phone_number rescue ""),
              "citizenship" => (patient_bean.citizenship rescue "")
          },
          "birthdate" => (Person.find(patient_bean.person_id).birthdate.to_date.strftime('%Y-%m-%d') rescue nil),
          "birthdate_estimated" => (patient_bean.birthdate_estimated.to_s == '0' ? false : true),
          "identifiers" => {},
          "current_residence"=> patient_bean.landmark,
          "current_village"=> patient_bean.current_residence,
          "current_district"=>  patient_bean.current_district,
          "home_village"=> patient_bean.home_village,
          "home_ta"=> patient_bean.traditional_authority,
          "home_district"=> patient_bean.home_district
      }
    end

  end

  def force_create
=begin
  When params is local, data['return_path'] is available
=end
    data = JSON.parse(params['data'])
    data['gender'] = data['gender'].match(/F/i) ? "Female" : "Male"
    data['birthdate'] = data['birthdate'].to_date.strftime("%Y-%m-%d")
    data['birthdate_estimated'] = ({'false' => 0, 'true' => 1}[data['birthdate_estimated']])
    data['birthdate_estimated'] = params['data']['birthdate_estimated'] if data['birthdate_estimated'].to_s.blank?
    person = {}, npid = nil
    p = nil
    if !data['return_path'].blank?
      person = {
          "person"  =>{
              "birthdate_estimated" => data['birthdate_estimated'],
              "attributes"         => data["attributes"],
              "birthdate"          => data['birthdate'],
              "addresses"          =>{"address1"=>data["current_residence"],
                                     'township_division' => data['current_ta'],
                                     "address2"=>data["home_district"],
                                     "city_village"=>data["current_village"],
                                     "state_province"=>data["current_district"],
                                     "neighborhood_cell"=>data["home_village"],
                                     "county_district"=>data["home_ta"]},
              "gender"            => data['gender'],
              "identifiers"           => (data["identifiers"].blank? ? {} : data["identifiers"]),
              "names"             =>{"family_name"=>  data["family_name"],
                                     "given_name"=>   data["given_name"],
                                     "middle_name"=> (data["middle_name"] || "")}
          }
      }

      response = DDE2Service.force_create_from_dde2(data, data['return_path'])
      npid = response['npid']

      person['person']['identifiers']['National id'] = npid
      p = DDE2Service.create_from_form(person)
    else
      #search from dde in case you want to replace the identifier
      npid = data['npid']

      person = {
          "person"  =>{
              "birthdate_estimated"      => data['birthdate_estimated'],
              "attributes"        =>data["attributes"],
              "birthdate"       => data['birthdate'],
              "addresses"         =>{"address1"=>data['addresses']["current_residence"],
                                     'township_division' => data['addresses']['current_ta'],
                                     "address2"=>data['addresses']["home_district"],
                                     "city_village"=>data['addresses']["current_village"],
                                     "state_province"=>data['addresses']["current_district"],
                                     "neighborhood_cell"=>data['addresses']["home_village"],
                                     "county_district"=>data['addresses']["home_ta"]},
              "gender"            => data['gender'],
              "identifiers"           => (data["identifiers"].blank? ? {} : data["identifiers"]),
              "names"             => {"family_name"=>data['names']["family_name"],
                                     "given_name"=>data['names']["given_name"],
                                     "middle_name"=> (data['names']["middle_name"] || "")}
            }
        }

       if npid.present?
         person['person']['identifiers']['National id'] = npid
         p = DDE2Service.create_from_form(person)

         response = DDE2Service.search_by_identifier(npid)
         if response.present?

           if response.first['npid'] != npid
             print_and_redirect("/patients/national_id_label?patient_id=#{p.id}", next_task(p.patient)) and return
           end
         end
       end
    end

    redirect_to next_task(p.patient)
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
 

require 'barby'
require 'barby/barcode/code_39'
require 'barby/outputter/png_outputter'
class PatientsController < GenericPatientsController

  def show
		session[:mastercard_ids] = []
		session_date = session[:datetime].to_date rescue Date.today
		@patient_bean = PatientService.get_patient(@patient.person)
		@encounters = @patient.encounters.find_by_date(session_date)
		@diabetes_number = DiabetesService.diabetes_number(@patient)
		@prescriptions = @patient.orders.unfinished.prescriptions.all
		@programs = @patient.patient_programs.all
		@alerts = alerts(@patient, session_date) rescue nil
	
		if !session[:location].blank?
			session["category"] = (session[:location] == "Paeds A and E" ? "paeds" : "adults")
		end
	
		#find the user priviledges
		@super_user = false
		@clinician  = false
		@doctor     = false
		@regstration_clerk  = false

		@category = session["category"] rescue ""

		#@ili = Observation.find(:all, :joins => [:concept => :name], :conditions =>
		#		["self.concept.fullname = ? AND value_coded IN (?) AND obs.voided = 0", "ILI",
		#		ConceptName.find(:all, :conditions => ["voided = 0 AND name = ?", "YES"]).collect{|o|
		#			o.concept_id}]).length

		#@sari = Observation.find(:all, :joins => [:concept => :name], :conditions =>
		#		["name = ? AND value_coded IN (?) AND obs.voided = 0", "SARI",
		#		ConceptName.find(:all, :conditions => ["voided = 0 AND name = ?", "YES"]).collect{|o|
		#			o.concept_id}]).length

		@user = current_user
		#@user_privilege = @user.user_roles.collect{|x|x.role.downcase}
    group_following = Concept.find_by_name('GROUP FOLLOWING').id
    ipd_program = Program.find_by_name('IPD program')
    active_ipd_program = PatientProgram.find(:last ,:conditions => ["patient_id =? AND
    date_completed IS NULL OR date_completed > NOW() AND program_id =?", @patient.id,
        ipd_program.id])
    encounter_type = EncounterType.find_by_name("ADMIT PATIENT")
    @current_team = nil
    unless active_ipd_program.blank?
      team_obs = Observation.find(:last, :joins =>[:encounter],
        :conditions => ["encounter_type =? AND concept_id =? AND person_id =?",
          encounter_type.id, group_following, @patient.id])
      @current_team = team_obs.answer_string.squish.titlecase rescue nil
    end

		user_roles = UserRole.find(:all,:conditions =>["user_id = ?", current_user.id]).collect{|r|r.role.downcase}
		inherited_roles = RoleRole.find(:all,:conditions => ["child_role IN (?)", user_roles]).collect{|r|r.parent_role.downcase}
		user_roles = user_roles + inherited_roles
		user_roles = user_roles.uniq

		if user_roles.include?("superuser")
			@super_user = true
		end
	
		if user_roles.include?("clinician")
			@clinician  = true
		end

		if user_roles.include?("doctor")
			@doctor = true
		end

		if user_roles.include?("regstration_clerk")
			@regstration_clerk  = true
		end
	
		if user_roles.include?("adults")
			@adults  = true
		end
	
		if user_roles.include?("paediatrics")
			@paediatrics  = true
		end
	
		if user_roles.include?("hmis lab order")
			@hmis_lab_order  = true
		end
	
		if user_roles.include?("spine clinician")
			@spine_clinician  = true
		end
	
		if user_roles.include?("lab")
			@lab  = true
		end

		@restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })

		@restricted.each do |restriction|
			@encounters = restriction.filter_encounters(@encounters)
			@prescriptions = restriction.filter_orders(@prescriptions)
			@programs = restriction.filter_programs(@programs)
		end

		@date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

		@location = Location.find(session[:location_id]).name rescue ""
		if @location.downcase == "outpatient" || params[:source]== 'opd'
			render :template => 'dashboards/opdtreatment_dashboard', :layout => false
		else
			@task = main_next_task(Location.current_location,@patient,session_date)
			@hiv_status = PatientService.patient_hiv_status(@patient)
			@reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
			@arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')
			render :template => 'patients/index', :layout => false
		end
  end

  def personal
    @links = []
    patient = Patient.find(params[:id])

    @links << ["Visit Summary (Print)","/patients/dashboard_print_opd_visit/#{patient.id}"]
    @links << ["National ID (Print)","/patients/dashboard_print_national_id/#{patient.id}"]
    @links << ["Demographics (Edit)","/patients/edit_demographics?patient_id=#{patient.id}"]
    @links << ["Past Visits (View)","/patients/past_visits_summary/#{patient.id}"]
    @links << ["Wrist band (print)","/patients/band_print?patient_id=#{patient.id}"]
    @links << ["Admission form (Print)","/patients/print_admission_form?patient_id=#{patient.id}"]
    if use_filing_number and not PatientService.get_patient_identifier(patient, 'Filing Number').blank?
      @links << ["Filing Number (Print)","/patients/print_filing_number/#{patient.id}"]
    end 

    if use_filing_number and PatientService.get_patient_identifier(patient, 'Filing Number').blank?
      @links << ["Filing Number (Create)","/patients/set_filing_number/#{patient.id}"]
    end 

    if use_user_selected_activities
      @links << ["Change User Activities","/user/activities/#{current_user.id}?patient_id=#{patient.id}"]
    end

    @links << ["Recent Lab Orders Label","/patients/recent_lab_orders?patient_id=#{patient.id}"]

    render :template => 'dashboards/personal_tab', :layout => false
  end
  
  def dashboard_print_opd_visit
    print_and_redirect("/patients/opd_visit_label/?patient_id=#{params[:id]}", "/patients/show/#{params[:id]}")
  end
 
  def opd_visit_label
    session_date = session[:datetime].to_date rescue Date.today
    print_string = opd_patient_visit_label(@patient, session_date) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end
	
	def mastercard
    @type = params[:type]
    
    #the parameter are used to re-construct the url when the mastercard is called from a Data cleaning report
    @quarter = params[:quarter]
    @arv_start_number = params[:arv_start_number]
    @arv_end_number = params[:arv_end_number]
    @show_mastercard_counter = false

    if params[:patient_id].blank?

      @patient_id = session[:mastercard_ids][session[:mastercard_counter]]
       
    elsif session[:mastercard_ids].length.to_i != 0
      @patient_id = params[:patient_id]
    else
      @patient_id = params[:patient_id]
    end

    unless params.include?("source")
      @source = params[:source] rescue nil
    else
      @source = nil
    end

    render :layout => false
    
  end

  def opd_patient_visit_label(patient, date = Date.today)
    result = Location.current_location.name.match(/outpatient/i).nil?

    if result == false
      return mastercard_visit_label(patient,date)
    else
      label = ZebraPrinter::StandardLabel.new
      label.font_size = 3
      label.font_horizontal_multiplier = 1
      label.font_vertical_multiplier = 1
      label.left_margin = 50
      units = {"WEIGHT"=>"kg", "HT"=>"cm"}
      encs = patient.encounters.find(:all,:conditions =>["DATE(encounter_datetime) = ?",date])
      encounter_type = EncounterType.find_by_name("ADMIT PATIENT")

      admission_enc = Encounter.find(:last, :conditions => ["patient_id =? AND
          encounter_type =?", patient.id, encounter_type.id])
      unless admission_enc.blank?
        first_enc = admission_enc.encounter_datetime.strftime("%d/%b/%Y")
        admission_time_concept_id =  Concept.find_by_name('ADMISSION TIME').id
        admission_time = admission_enc.observations.find(:last, :conditions => ["concept_id =?",
            admission_time_concept_id]).answer_string.squish rescue nil
        admission_time = (Time.parse(admission_time) rescue nil) unless admission_time.blank?
        admission_time = (admission_time.strftime("%H:%M") rescue nil) unless admission_time.blank?
        first_enc = first_enc.to_s + ' ' + admission_time.to_s
      else
        first_enc = encs.first.encounter_datetime.strftime("%d/%b/%Y %H:%M")
      end
      
      return nil if encs.blank?

      label.draw_multi_text("Visit: #{first_enc}" +
    " - #{encs.last.encounter_datetime.strftime("%d/%b/%Y %H:%M")}", :font_reverse => true)

      encs.each {|encounter|

          if encounter.name.upcase.include?('TREATMENT')
            o = encounter.orders.collect{|order| order.to_s if order.order_type_id == OrderType.find_by_name('Drug Order').order_type_id}.join("\n")
            o = "No prescriptions have been made" if o.blank?
            o = "TREATMENT NOT DONE" if treatment_not_done(encounter.patient, date)
            label.draw_multi_text("#{o}", :font_reverse => false)

          elsif encounter.name.upcase.include?("PROCEDURES DONE")
            procs = ["Procedures - "]
            procs << encounter.observations.collect{|observation| 
              observation.answer_string.squish if !observation.concept.fullname.match(/Workstation location/i)
            }.compact.join("; ")
            label.draw_multi_text("#{procs}", :font_reverse => false)

          elsif encounter.name.upcase.include?('UPDATE HIV STATUS')
            hiv_status = []
            encounter.observations.each do |observation|
             next if !observation.concept.fullname.match(/HIV STATUS/i)
             hiv_status << 'HIV Status - ' + observation.answer_string.to_s rescue ''
            end
            label.draw_multi_text("#{hiv_status}", :font_reverse => false)

          elsif encounter.name.upcase.include?('DIAGNOSIS')
            obs = ["Diagnoses - "]
            obs << encounter.observations.collect{|observe|
              "#{observe.answer_string}".squish rescue nil if observe.concept.fullname.upcase.include?('DIAGNOSIS')}.compact.join("; ")
            obs
            label.draw_multi_text("#{obs}", :font_reverse => false)
            
					elsif encounter.name.upcase.include?("VITALS")
						string = []
						encounter.observations.each do |observation|
							concept_name = observation.concept.concept_names.last.name rescue ''
							next if concept_name.match(/Workstation location/i)
							string << observation.to_s(["short", "order"]).squish + units[concept_name.upcase].to_s
						end
						label.draw_multi_text("Vitals - " + string.join(', '), :font_reverse => false)
          end

      }
     
     program_id = Program.find_by_name('IPD PROGRAM').id
     ipd_program = patient.patient_programs.local.select{|p| p.program_id == program_id }.last rescue nil
     date_enrolled = ipd_program.date_enrolled.strftime("%a, %d/%b/%Y") rescue nil

     admit_to_ward_concept = Concept.find_by_name("ADMIT TO WARD")
     admission_obs  = Observation.find(:last, :conditions => ["person_id =? AND concept_id =?", patient.id, admit_to_ward_concept.id]) rescue nil
     date_admitted = admission_obs.obs_datetime.strftime("%a, %d/%b/%Y") rescue nil
     ward_admitted = admission_obs.answer_string.squish rescue nil
     label.draw_multi_text("Date Admitted - " + date_admitted, :font_reverse => false)
     label.draw_multi_text("Ward Admitted - " + ward_admitted, :font_reverse => false)

			['OPD PROGRAM','IPD PROGRAM'].each do |program_name|		
					program_id = Program.find_by_name(program_name).id
					state = patient.patient_programs.local.select{|p| p.program_id == program_id}.last.patient_states.last rescue nil

					next if state.nil?
					
					state_start_date = state.start_date.to_date	
					state_name = state.program_workflow_state.concept.fullname
					
					if ((state_start_date == session[:datetime]) || (state_start_date == Date.today)) && (state_name.upcase != 'FOLLOWING')					
      			label.draw_multi_text("Outcome - #{state_name}", :font_reverse => false)
      		end
			end

      label.draw_multi_text("Processed by: #{current_user.name rescue ''} at " +
        " #{Location.current_location.name rescue ''}", :font_reverse => true)
      
      label.print(1)
    end
  end

  def past_diagnoses
    @patient_ID = params[:patient_id]  #--removedas I am only passing the patient_id  || params[:id] || session[:patient_id]
    @patient = Patient.find(@patient_ID) rescue nil 
    #@remote_visit_diagnoses = @patient.remote_visit_diagnoses rescue nil
    #@remote_visit_treatments = @patient.remote_visit_treatments rescue nil
   # @local_diagnoses = PatientService.visit_diagnoses(@patient.id)
   # @local_treatments = @patient.visit_treatments

		
   
    @past_local_cases = {}    
    @patient.encounters.each{|e| 
      @past_local_cases[e.encounter_datetime.strftime("%Y-%m-%d")] = {} if e.encounter_datetime.to_date < (session[:datetime].to_date rescue Date.today.to_date)   
      }
    
    @patient.encounters.each{|e| 
      @past_local_cases[e.encounter_datetime.strftime("%Y-%m-%d")][e.name] = encounter_summary(e)  if e.encounter_datetime.to_date < (session[:datetime].to_date rescue Date.today.to_date)   
      }
    
    @past_local_cases = @past_local_cases.sort.reverse!
    render :layout => false
    
  end
  
	def diagnosis_summary(encounter)
      diagnosis_array = []
      encounter.observations.each{|observation|
        next if observation.obs_group_id != nil || observation.concept.fullname.upcase != 'DIAGNOSIS'
        observation_string =  observation.answer_string
        child_ob = child_observation(observation)
        while child_ob != nil
          observation_string += " #{child_ob.answer_string}"
          child_ob = child_observation(child_ob)
        end
        diagnosis_array << observation_string
        diagnosis_array << " : "
      }
      
      my_hash = []
      encounter.observations.each{|observation|
        my_hash << observation.concept.fullname 
      }
 			#raise my_hash.to_yaml           
      diagnosis_array.compact.to_s.gsub(/ : $/, "")
	end
	
	def encounter_summary(encounter)
		name = encounter.type.name
    if name == 'TREATMENT'
      o = encounter.orders.collect{|order| order.to_s}.join("\n")
      o = "TREATMENT NOT DONE" if encounter.type.name == 'X'
      o = "No prescriptions have been made" if o.blank?
      o
    elsif name.upcase.include?('DIAGNOSIS')
      diagnosis_array = []
      encounter.observations.each{|observation|
        next if observation.obs_group_id != nil || !observation.concept.fullname.upcase.include?('DIAGNOSIS')
        observation_string =  observation.answer_string
        child_ob = child_observation(observation)
        while child_ob != nil
          observation_string += " #{child_ob.answer_string}"
          child_ob = child_observation(child_ob)
        end
        diagnosis_array << observation_string
        diagnosis_array << " : "
      }
      
         
      diagnosis_array.compact.to_s.gsub(/ : $/, "")

    elsif name == 'LAB ORDERS'

     x = encounter.observations.collect{|observation|
     	 next if observation.concept.fullname.upcase == "WORKSTATION LOCATION"
       lab_obs_lab_results_string(observation).gsub("LAB TEST SERIAL NUMBER: ", "LAB ID: ")
      }.compact.join(",<br /> ")
		end
	end		

  def child_observation(obs)
    Observation.find(:first, :conditions => ["obs_group_id =?", obs.id])
  end
  
  # Added to filter Chronic Conditions and Influenza Data
  def lab_obs_lab_results_string(observation)
    if observation.answer_concept
      if !observation.answer_concept.fullname.include?("NO")
        "#{(observation.concept.fullname == "LAB TEST RESULT" ? "<b>#{observation.answer_concept.fullname rescue nil}</b>" : 
        "#{observation.concept.fullname}: #{observation.answer_concept.fullname rescue nil}#{observation.value_text rescue nil}#{observation.value_numeric rescue nil}") rescue nil}"
      end
    else
      "#{observation.concept.fullname rescue nil}: #{observation.value_text rescue 1 }#{observation.value_numeric rescue 2 }"
    end
  end
  
  def modify_demographics
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @field = params[:field]
    render :partial => "edit_demographics", :field =>@field, :layout => true and return
  end
  
  def update_demographics

    person = Person.find(params['person_id']) rescue ''
    birth_month = params[:person][:birth_month] rescue ''
    birth_day = params[:person][:birth_day] rescue ''
    birth_year = params[:person][:birth_year] rescue ''
    birth_params = (birth_day + '-' + birth_month + '-' + birth_year).to_date rescue ''
    if birth_year != nil
    if birth_params > Date.today
      flash[:error] = 'The date you have entered is invalid. Try again'
      redirect_to(:action => 'modify_demographics', :patient_id => person.patient.patient_id, :field => 'birthdate') and return
    end
    end
   update_demo_graphics(params)
   redirect_to :action => 'edit_demographics', :patient_id => params['person_id'] and return
  end
  
  def update_demo_graphics(params)
    person = Person.find(params['person_id'])
    
    if params.has_key?('person')
      params = params['person']
    end
    
    address_params = params["addresses"]
    names_params = params["names"]
    patient_params = params["patient"]
    person_attribute_params = params["attributes"]

    params_to_process = params.reject{|key,value| key.match(/addresses|patient|names|attributes/) }
    birthday_params = params_to_process.reject{|key,value| key.match(/gender/) }

    person_params = params_to_process.reject{|key,value| key.match(/birth_|age_estimate/) }
   
    if !birthday_params.empty?
    
      if birthday_params["birth_year"] == "Unknown"
        PatientService.set_birthdate_by_age(person, birthday_params["age_estimate"])
      else
        PatientService.set_birthdate(person, birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
      end
      
      person.birthdate_estimated = 1 if params["birthdate_estimated"] == 'true'
      person.save
    end
    
    person.update_attributes(person_params) if !person_params.empty?
    person.names.first.update_attributes(names_params) if names_params
    person.addresses.first.update_attributes(address_params) if address_params

    #update or add new person attribute
    person_attribute_params.each{|attribute_type_name, attribute|
        attribute_type = PersonAttributeType.find_by_name(attribute_type_name.humanize.titleize) || PersonAttributeType.find_by_name("Unknown id")
        #find if attribute already exists
        exists_person_attribute = PersonAttribute.find(:first, :conditions => ["person_id = ? AND person_attribute_type_id = ?", person.id, attribute_type.person_attribute_type_id]) rescue nil 
        if exists_person_attribute
          exists_person_attribute.update_attributes({'value' => attribute})
        else
          person.person_attributes.create("value" => attribute, "person_attribute_type_id" => attribute_type.person_attribute_type_id)
        end
      } if person_attribute_params

  end
  
  # Influenza method for accessing the influenza view
  def influenza
    
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @person = Person.find(@patient.patient_id)
		
		@patient_bean = PatientService.get_patient(@person)
    @gender = @patient_bean.sex
    
    if @patient_bean.age > 15
    	session["category"] = 'adults'
    else
    	session["category"] = 'peads'    
    end
    render :layout => "multi_touch"
    
  end

  def influenza_recruitment

    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @influenza_data = Array.new()
    @influenza_concepts = Array.new()

    excluded_concepts = ["INFLUENZA VACCINE IN THE LAST 1 YEAR",
                         "CURRENTLY (OR IN THE LAST WEEK) TAKING ANTIBIOTICS",
                         "CURRENT SMOKER","WERE YOU A SMOKER 3 MONTHS AGO",
                         "PREGNANT?","RDT OR BLOOD SMEAR POSITIVE FOR MALARIA",
                         "PNEUMOCOCCAL VACCINE","MEASLES VACCINE",
                         "MUAC LESS THAN 11.5 (CM)","WEIGHT",
                         "PATIENT CURRENTLY SMOKES","IS PATIENT PREGNANT?"]
        
    influenza_data = @patient.encounters.current.all(
                                        :conditions => ["encounter.encounter_type = ?",EncounterType.find_by_name('INFLUENZA DATA').encounter_type_id],
                                        :include => [:observations]
                                      ).map{|encounter| encounter.observations.all}.flatten.compact.map{|obs|
                                        @influenza_data.push("#{obs.concept.fullname}: #{obs.answer_string}") if !excluded_concepts.include?(obs.to_s.split(':')[0])
                                      }

    if @influenza_data.length == 0
     redirect_to :action => 'show', :patient_id => @patient.id and return
    end
    render :layout => "multi_touch"
  end
  
  # Influenza method for accessing the influenza view
  def chronic_conditions

    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @person = Person.find(@patient.patient_id)

    @gender = @person.gender

  end

  def treatment_not_done(patient, date)
    self.current_treatment_encounter(patient, date).first.observations.all(
      :conditions => ["obs.concept_id = ?", ConceptName.find_by_name("TREATMENT").concept_id]).last rescue false
  end

  def current_treatment_encounter(patient, date, force = false)
    type = EncounterType.find_by_name('TREATMENT')

    encounter = patient.encounters.find(:all,:conditions =>["encounter_type = ? AND
                                  DATE(encounter_datetime) = ?", type,date])
    return encounter
  end
  
  def influenza_info
    @patient_id = params[:patient_id]  #--removed as I am only passing the patient_id  || params[:id] || session[:patient_id]
    @patient = Patient.find(@patient_id) rescue nil
    @influenza_data = Array.new()
    excluded_concepts = Array.new()
    @opd_influenza_data = Array.new()

    excluded_concepts = ["INFLUENZA VACCINE IN THE LAST 1 YEAR",
                         "CURRENTLY (OR IN THE LAST WEEK) TAKING ANTIBIOTICS",
                         "CURRENT SMOKER","WERE YOU A SMOKER 3 MONTHS AGO",
                         "PREGNANT?","RDT OR BLOOD SMEAR POSITIVE FOR MALARIA",
                         "PNEUMOCOCCAL VACCINE","MEASLES VACCINE",
                         "MUAC LESS THAN 11.5 (CM)","WEIGHT",
                         "PATIENT CURRENTLY SMOKES","IS PATIENT PREGNANT?"]

   @influenza_data = @patient.encounters.all(
                                        :conditions => ["encounter.encounter_type = ?",EncounterType.find_by_name('INFLUENZA DATA').encounter_type_id],
                                        :include => [:observations]
                                      ).map{|encounter| encounter.observations.all}.flatten.compact.map{|obs|
                                        @influenza_data.push("#{obs.concept.fullname.humanize}: #{obs.answer_string} ") if !excluded_concepts.include?(obs.to_s.split(':')[0])
                                      }
    if @influenza_data.length == 0
      @opd_influenza_data << "None"
    else
      @opd_influenza_data = @influenza_data.last
    end
    @ipd_influenza_data = remote_influenza_info(@patient)
    
    render :layout => false
  end
  
  def remote_influenza_info(patient)

		patient_bean = PatientService.get_patient(patient.person)
		
    #this gets the influenza info from IPD
      given_params = {:person => {:patient => { :identifiers => {"National id" => patient_bean.national_id }}}}
      national_id_params = CGI.unescape(given_params.to_param).split('&').map{|elem| elem.split('=')}
      mechanize_browser = Mechanize.new
      demographic_servers = JSON.parse(GlobalProperty.find_by_property("demographic_server_ips_and_local_port").property_value)   rescue []

      result = demographic_servers.map{|demographic_server, local_port|
       begin
             
          output = mechanize_browser.post("http://localhost:local_port/patients/retrieve_	", national_id_params).body

        rescue Timeout::Error
         return []
         rescue
         return []
       end
       output if output and output.match(/person/)
       }.sort{|a,b|b.length <=> a.length}.first

     # result ? JSON.parse(result) : nil
     
     result = JSON.parse(output) rescue nil

  end
  
  def chronic_conditions_info
    @patient_id = params[:patient_id]
    @patient = Patient.find(@patient_id) rescue nil
    @ipd_chronic_conditions = Array.new()

    @ipd_chronic_conditions = get_remote_chronic_conditions(@patient)
    #Add None element if no conditions are returned from remote

    if @ipd_chronic_conditions.length == 0
      @ipd_chronic_conditions << "None"
    end
   # raise @ipd_chronic_conditions.to_yaml
    @opd_chronic_conditions = local_chronic_conditions(@patient_id)
    if @opd_chronic_conditions.length == 0
      @opd_chronic_conditions << "None"
    end
    render :layout => false
  end
  
  def get_remote_chronic_conditions(patient)
  
		patient_bean = PatientService.get_patient(patient.person)
  
    #this gets the influenza info from IPD
      given_params = {:person => {:patient => { :identifiers => {"National id" => patient_bean.national_id }}}}
      national_id_params = CGI.unescape(given_params.to_param).split('&').map{|elem| elem.split('=')}
      mechanize_browser = Mechanize.new
      demographic_servers = JSON.parse(GlobalProperty.find_by_property("demographic_server_ips_and_local_port").property_value)   rescue []

      result = demographic_servers.map{|demographic_server, local_port|
      begin
          output = mechanize_browser.post("http://localhost:local_port/patients/remote_chronic_conditions", national_id_params).body

      rescue Timeout::Error
         return []
         rescue
         return []
      end
       output if output and output.match(/person/)
      }.sort{|a,b|b.length <=> a.length}.first

     #result ? JSON.parse(result) : nil

     result = JSON.parse(output) rescue []

  end
  
  def local_chronic_conditions(patient_id)

    @patient = Patient.find(patient_id) rescue nil
    @chronic_conditions = @patient.encounters.all(
                                        :conditions => ["encounter.encounter_type = ?",EncounterType.find_by_name('CHRONIC CONDITIONS').encounter_type_id],
                                        :include => [:observations]
                                      ) rescue []
   
    chronic_conditions_array = Array.new
    
    if @chronic_conditions.length == 0
      chronic_conditions_array << "None"
    else
      @chronic_conditions.each do |encounter|
          chronic_conditions_array << encounter.to_s
      end
    end
    return chronic_conditions_array
    
  end

  def band_print

    @patient = Patient.find(params[:patient_id]) rescue nil
    #raise @patient.inspect
    print_string = patient_wrist_band_barcode_label(@patient.id) 
    #raise print_string.inspect
    if !print_string.blank?

      send_data(print_string,
        :type=>"application/label; charset=utf-8",
        :stream=> false,
        :filename=>"#{params[:patient_id]}#{rand(10000)}.bcl",
        :disposition => "inline") and return
    end

    #redirect_to next_task(@patient)

  end

  def patient_wrist_band_barcode_label(patient)
    person = Person.find(patient) rescue nil
    patient_bean = PatientService.get_patient(person) rescue nil
    obs = Observation.find_by_sql("SELECT * FROM obs o INNER JOIN encounter e WHERE
              e.encounter_type=(SELECT encounter_type_id FROM encounter_type WHERE name = 'ADMIT PATIENT')
              AND o.person_id = #{patient} AND o.value_text IS NOT NULL AND
              o.concept_id=(SELECT concept_id FROM concept_name WHERE name = 'ADMIT TO WARD')
              AND o.voided = 0 ORDER BY o.obs_datetime DESC LIMIT 1").first rescue nil
    ward = obs.value_text.humanize rescue nil
    program_id = Program.find_by_name('IPD PROGRAM').id
    @patient = person.patient
    date_enrolled = @patient.patient_programs.current.local.select{|p| p.program_id == program_id }.last.date_enrolled.to_date rescue nil
    patient_name = patient_bean.name rescue nil
    unless patient_name.blank?
      if (patient_name.size > 17)
        patient_name = patient_name[0..18] + '..'
      end
    end
    
    unless ward.blank?
      if (ward.size > 15)
        ward = ward[0..16] + '..'
      end
    end
=begin
  "^XA~TA000~JSN^LT0^MNM^MTD^PON^PMN^LH0,0^JMA^PR2,2^MD21^JUS^LRN^CI0^XZ
  ^XA
  ^FO200,1250^ADR,36,20^FD#{(patient_bean.name.titlecase + '(' + person.gender + ')' rescue nil)}^FS
  ^FO160,1250^ADR,36,20^FDAdmitted on: #{(obs.encounter_datetime.strftime("%d/%m/%Y") rescue nil)}^FS
  ^FO120,1250^ADR,36,20^FDWard:#{obs.value_text rescue nil}^FS
  ^FO80,1850^BY4^BCR,200,N,N,N^FD#{(patient_bean.national_id_with_dashes rescue nil)}^FS
  ^FO40,1950^ADR,36,20^FD#{(patient_bean.national_id_with_dashes rescue nil)}^FS
  ^XZ"
=end
    "^XA~TA000~JSN^LT0^MNM^MTD^PON^PMN^LH0,0^JMA^PR2,2^MD21^JUS^LRN^CI0^XZ
  ^XA
  ^FO240,1250^ADR,36,20^FD#{(patient_name.titlecase + '(' + person.gender + ')' rescue nil)}^FS
  ^FO200,1250^ADR,36,20^FDBorn on: #{patient_bean.birth_date rescue nil}^FS
  ^FO160,1250^ADR,36,20^FDAdmitted on: #{(date_enrolled.strftime("%d/%m/%Y") rescue nil)}^FS
  ^FO120,1250^ADR,36,20^FDWard:#{ward}^FS
  ^FO80,1850^BY4^BCR,200,N,N,N^FD#{(patient_bean.national_id_with_dashes rescue nil)}^FS
  ^FO40,1950^ADR,36,20^FD#{(patient_bean.national_id_with_dashes rescue nil)}^FS
  ^XZ"
  end

  def admission_history
    @logo = CoreService.get_global_property_value('logo').to_s rescue nil
    patient_id = params[:id]
    patient = Patient.find(patient_id)
    program_id = Program.find_by_name('IPD PROGRAM').id
    date_enrolled = patient.patient_programs.current.local.select{|p| p.program_id == program_id }.last.date_enrolled.to_date rescue nil
    unless date_enrolled.blank?
      @date_enrolled = date_enrolled
    else
      date_enrolled = patient.patient_programs.local.select{|p| p.program_id == program_id }.last.date_enrolled.to_date rescue nil
      @date_enrolled = date_enrolled
    end
    today = Date.today
    @patient_bean = PatientService.get_patient(patient.person)
   # observations = Observation.find(:all, :conditions => ["person_id =? AND
       # DATE(obs_datetime) >= ? AND DATE(obs_datetime) <= ?",patient_id, date_enrolled,today])

    encounters = Encounter.find(:all, :conditions => ["patient_id =? AND
        DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ?",patient_id, date_enrolled,today],\
        :order => "encounter_datetime ASC")
    
    admission_history = {}
    encounters.each do |encounter|
      next if encounter.type.name.match(/Treatment|Dispensing/i)
      admission_history[encounter.id] = {}
      admission_history[encounter.id]["encounter_datetime"] = encounter.encounter_datetime
      admission_history[encounter.id]["encounter_type"] = encounter.type.name

      unless (User.find_by_user_id(encounter.provider_id).blank?)
        provider = User.find_by_user_id(encounter.provider_id).person.names[0]
      else
        provider = encounter.provider.names[0]
      end
      provider_names = provider.given_name.first.to_s + '.' + provider.family_name.to_s
      admission_history[encounter.id]["provider_details"] = provider_names
      answer_string = []
      encounter.observations.each do |obs|
        answer_string << obs.to_s
      end
      answer_string.delete_if{|answer|answer.match(/Workstation location/i)}
      test = ""
      answer_string.each do |answer|
        string  = answer.split(":")
        text = string[0].to_s + ": " + "<b>" + string[1].to_s.squish + "</b>"
        text+= ", " if answer_string.size > 1 && answer_string[-1] != answer
        test += text
      end
      #raise test.inspect
      admission_history[encounter.id]["answer_string"] = test
    end
     @admission_history = admission_history.sort_by {|key,value| key}
    render:layout => "menu"
  end

  def current_lab_orders
    patient_id = params[:id]
    encounters =  Encounter.find(:all, :conditions => ["encounter_type =? AND DATE(encounter_datetime) =? AND
        patient_id =?", EncounterType.find_by_name('lab orders').id, Date.today, patient_id])
    @current_lab_orders = {}
    encounters.each do |enc|
      @current_lab_orders[enc.encounter_datetime]={}
      enc.observations.each do |obs|
        next if obs.concept.fullname.match(/Workstation/i)
        next if !obs.obs_group_id.blank?
        child_obs = Observation.find(:all, :conditions => ["obs_group_id =?", obs.id])
        unless child_obs.blank?
          child_obs.each do |child|
            if @current_lab_orders[enc.encounter_datetime][obs.answer_string.squish].blank?
              @current_lab_orders[enc.encounter_datetime][obs.answer_string.squish] = child.answer_string.squish
            else
                @current_lab_orders[enc.encounter_datetime][obs.answer_string.squish] += ', ' + child.answer_string.squish.to_s
            end
          end
        else
          @current_lab_orders[enc.encounter_datetime][obs.answer_string.squish] = "N/A"
        end
      end
    end
    render :template => 'dashboards/current_lab_orders_tab', :layout => false
  end

  def historical_lab_orders
    patient_id = params[:id]
    encounters =  Encounter.find(:all, :conditions => ["encounter_type =? AND DATE(encounter_datetime) < ? AND
        patient_id =?", EncounterType.find_by_name('lab orders').id, Date.today, patient_id])
    @prev_lab_orders = {}
    encounters.each do |enc|
      @prev_lab_orders[enc.encounter_datetime.to_date]={}
      enc.observations.each do |obs|
        next if obs.concept.fullname.match(/Workstation/i)
        next if !obs.obs_group_id.blank?
        child_obs = Observation.find(:all, :conditions => ["obs_group_id =?", obs.id])
        unless child_obs.blank?
          child_obs.each do |child|
            if @prev_lab_orders[enc.encounter_datetime.to_date][obs.answer_string.squish].blank?
              @prev_lab_orders[enc.encounter_datetime.to_date][obs.answer_string.squish] = child.answer_string.squish
            else
                @prev_lab_orders[enc.encounter_datetime.to_date][obs.answer_string.squish] += ', ' + child.answer_string.squish.to_s
            end
          end
        else
          @prev_lab_orders[enc.encounter_datetime.to_date][obs.answer_string.squish] = "N/A"
        end
      end
    end
     render :template => 'dashboards/historical_lab_orders_tab', :layout => false
  end

  def proceed_to_radiology
      @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) # rescue nil
      # rad_link = GlobalProperty.find_by_property("rad_link").property_value.gsub(/http\:\/\//, "") rescue nil
      # ipd_link = GlobalProperty.find_by_property("ipd_link").property_value rescue nil

      token = session[:token]
      location_id = session[:location_id]

      rad_link = CoreService.get_global_property_value("rad_url") rescue nil
      ipd_link = CoreService.get_global_property_value("ipd_url") rescue nil
      #if !rad_link.nil? && !ipd_link.nil? # && foreign_links.include?(pos)
      unless(rad_link.blank? && ipd_link.blank? )
          response = RestClient.post("http://#{rad_link}/single_sign_on/get_token",
            {"login"=>session[:username], "password"=>session[:password]}) rescue nil
           #raise response.inspect
          if !response.nil?
            response = JSON.parse(response) rescue ""

            token = response["auth_token"]
            session[:token] = response["auth_token"]
          else
            flash[:error] = "Could not get valid token"
            redirect_to next_task(@patient) and return
          end

      end
     
      redirect_to "http://#{rad_link}/single_sign_on/single_sign_in?location=#{
      (!location_id.nil? and !location_id.blank? ? location_id : "721")}&current_location=#{
      (!location_id.nil? and !location_id.blank? ? location_id : "721")}&" +
        (!session[:datetime].blank? ? "current_time=#{ (session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}&" : "") +
        "return_uri=http://#{ipd_link}/patients/show/#{@patient.id}&destination_uri=http://#{rad_link}" +
        "/investigation/new/#{@patient.id}?from_ipd=true&auth_token=#{token}" and return
  end

  def admission_form
    @logo = CoreService.get_global_property_value('logo')
    @current_location_name = Location.current_health_center.name
    patient = Patient.find(params[:patient_id])
    @patient_bean = PatientService.get_patient(patient.person)
    #raise @patient_bean.inspect
    render :layout => "menu"
  end

  def admission_form_printable
    @logo = CoreService.get_global_property_value('logo')
    @current_location_name = Location.current_health_center.name
    patient_id = params[:patient_id]
    patient = Patient.find(params[:patient_id])
    @patient_bean = PatientService.get_patient(patient.person)
    admission_enc = Encounter.find(:last, :conditions => ["encounter_type =? AND patient_id =?",
        EncounterType.find_by_name('ADMIT PATIENT').id, patient_id])
    @date_admitted = admission_enc.encounter_datetime rescue nil
    @team_following = admission_enc.observations.find(:last, :conditions => ["concept_id =?",\
    Concept.find_by_name('GROUP FOLLOWING').id]).value_text rescue nil
    barcode_value = @patient_bean.national_id_with_dashes
    full_path = "#{RAILS_ROOT}/public/images/barcode_#{barcode_value}.png"
    barcode = Barby::Code39.new(barcode_value)
    File.open(full_path, 'w') { |f|
      f.write barcode.to_png(:margin => 3, :xdim => 2, :height => 80)
    }
    render :layout => false
  end

  def print_admission_form
    location = request.remote_ip rescue ""
    @patient = Patient.find(params[:patient_id] || params[:id]) rescue nil
    patient_bean = PatientService.get_patient(@patient.person)
    if @patient
      current_printer = ""

      wards = CoreService.get_global_property_value("facility.ward.printers").split(",") rescue []
      wards.each{|ward|
        current_printer = ward.split(":")[1] if ward.split(":")[0].upcase == location
      } rescue []
      
        t1 = Thread.new{
          Kernel.system "wkhtmltopdf --margin-top 0 --margin-bottom 0 -s A4 http://" +
            request.env["HTTP_HOST"] + "\"/patients/admission_form_printable/" +
            "?patient_id=#{@patient.id}" + "\" /tmp/output-#{@patient.id}" + ".pdf \n"
          
        }
        file = "/tmp/output-#{@patient.id}" + ".pdf"
        t2 = Thread.new{
          sleep(3)
          print(file, current_printer,patient_bean)
        }

    end
    redirect_to "/patients/show/#{params[:patient_id]}" and return
  end
  def print(file_name, current_printer, patient_bean)
    sleep(3)
    if (File.exists?(file_name))
     Kernel.system "lp -o sides=two-sided-long-edge -o fitplot #{(!current_printer.blank? ? '-d ' + current_printer.to_s : "")} #{file_name}"
     `rm #{RAILS_ROOT}/public/images/barcode_#{patient_bean.national_id_with_dashes}.png`
    else
      print(file_name)
    end
  end
end
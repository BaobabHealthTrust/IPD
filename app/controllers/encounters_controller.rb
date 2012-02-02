class EncountersController < ApplicationController
  def create(params=params, session=session)
    #raise params.to_yaml

    @patient = Patient.find(params[:encounter][:patient_id]) rescue nil
    if params[:location]
      if @patient.nil?
        @patient = Patient.find_with_voided(params[:encounter][:patient_id])
      end

      Person.migrated_datetime = params['encounter']['date_created']
      Person.migrated_creator  = params['encounter']['creator'] rescue nil

      # set current location via params if given
      Location.current_location = Location.find(params[:location])
    end
    
    if params['encounter']['encounter_type_name'].to_s.upcase == "APPOINTMENT" && !params[:report_url].nil? && !params[:report_url].match(/report/).nil?
        concept_id = ConceptName.find_by_name("RETURN VISIT DATE").concept_id
        encounter_id_s = Observation.find_by_sql("SELECT encounter_id
                       FROM obs
                       WHERE concept_id = #{concept_id} AND person_id = #{@patient.id}
                       AND DATE(value_datetime) = DATE('#{params[:old_appointment]}') AND voided = 0").map{|obs| obs.encounter_id}.each do |encounter_id|Encounter.find(encounter_id).void end   
    end

    # Encounter handling
    encounter = Encounter.new(params[:encounter])
    unless params[:location]
      encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
    else
      encounter.encounter_datetime = params['encounter']['encounter_datetime']
    end

    if !params[:filter][:provider].blank?
     user_person_id = User.find_by_username(params[:filter][:provider]).person_id
     encounter.provider_id = user_person_id
    else
     user_person_id = User.find_by_user_id(encounter[:provider_id]).person_id
     encounter.provider_id = user_person_id
    end

    encounter.save    

    # Observation handling
    (params[:observations] || []).each do |observation|

      # Check to see if any values are part of this observation
      # This keeps us from saving empty observations
      values = ['coded_or_text', 'coded_or_text_multiple', 'group_id', 'boolean', 'coded', 'drug', 'datetime', 'numeric', 'modifier', 'text'].map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      observation[:value_text] = observation[:value_text].join(", ") if observation[:value_text].present? && observation[:value_text].is_a?(Array)
      observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
      observation[:encounter_id] = encounter.id
      observation[:obs_datetime] = encounter.encounter_datetime || Time.now()
      observation[:person_id] ||= encounter.patient_id
      observation[:concept_name].upcase ||= "DIAGNOSIS" if encounter.type.name.upcase == "OUTPATIENT DIAGNOSIS"
      
      # Handle multiple select

      if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(String)
        observation[:value_coded_or_text_multiple] = observation[:value_coded_or_text_multiple].split(';')
      end
      
      if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(Array)
        observation[:value_coded_or_text_multiple].compact!
        observation[:value_coded_or_text_multiple].reject!{|value| value.blank?}
      end  
      
      # convert values from 'mmol/litre' to 'mg/declitre'
      if(observation[:measurement_unit])
        observation[:value_numeric] = observation[:value_numeric].to_f * 18 if ( observation[:measurement_unit] == "mmol/l")
        observation.delete(:measurement_unit)
      end

      if(observation[:parent_concept_name])
        concept_id = Concept.find_by_name(observation[:parent_concept_name]).id rescue nil
        observation[:obs_group_id] = Observation.find(:first, :conditions=> ['concept_id = ? AND encounter_id = ?',concept_id, encounter.id]).id rescue ""
        observation.delete(:parent_concept_name)
      end
      
      extracted_value_numerics = observation[:value_numeric]
      extracted_value_coded_or_text = observation[:value_coded_or_text]

      if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(Array) && !observation[:value_coded_or_text_multiple].blank?
        
        values = observation.delete(:value_coded_or_text_multiple)
        values.each do |value| 
            observation[:value_coded_or_text] = value
            if observation[:concept_name].humanize == "Tests ordered"
                observation[:accession_number] = Observation.new_accession_number 
            end
            Observation.create(observation) 
        end
      elsif extracted_value_numerics.class == Array
            
        extracted_value_numerics.each do |value_numeric|
          observation[:value_numeric] = value_numeric
          Observation.create(observation)
        end
        
      else      
        observation.delete(:value_coded_or_text_multiple)

        Observation.create(observation)
      end
    end

    # Program handling
    date_enrolled = params[:programs][0]['date_enrolled'].to_time rescue nil
    date_enrolled = session[:datetime] || Time.now() if date_enrolled.blank?
    (params[:programs] || []).each do |program|
      # Look up the program if the program id is set      
      @patient_program = PatientProgram.find(program[:patient_program_id]) unless program[:patient_program_id].blank?
      # If it wasn't set, we need to create it
      unless (@patient_program)
        @patient_program = @patient.patient_programs.create(
          :program_id => program[:program_id],
          :date_enrolled => date_enrolled)          
      end
      # Lots of states bub
      unless program[:states].blank?
        #adding program_state start date
        program[:states][0]['start_date'] = date_enrolled
      end
      (program[:states] || []).each {|state| @patient_program.transition(state) }
    end

    # Identifier handling
    (params[:identifiers] || []).each do |identifier|
      # Look up the identifier if the patient_identfier_id is set      
      @patient_identifier = PatientIdentifier.find(identifier[:patient_identifier_id]) unless identifier[:patient_identifier_id].blank?
      
      # Create or update
      if @patient_identifier
        @patient_identifier.update_attributes(identifier)      
      else
        @patient_identifier = @patient.patient_identifiers.create(identifier)
      end
    end

    # person attribute handling
    (params[:person] || []).each do | type , attribute |
      # Look up the attribute if the person_attribute_id is set  
      
      @person_attribute = nil
      # Create or update

      if not @person_attribute.blank?
        @patient_identifier.update_attributes(person_attribute)      
      end
  
    end

    # Go to the next task in the workflow (or dashboard)
    # only redirect to next task if location parameter has not been provided
    unless params[:location]
    #find a way of printing the lab_orders labels
     if params['encounter']['encounter_type_name'] == "LAB ORDERS"
       redirect_to"/patients/print_lab_orders/?patient_id=#{@patient.id}"
     else
      if params['encounter']['encounter_type_name'].to_s.upcase == "APPOINTMENT" && !params[:report_url].nil? && !params[:report_url].match(/report/).nil?
         redirect_to  params[:report_url].to_s and return
      end
      redirect_to next_task(@patient)
     end
    else
      if params[:voided]
        encounter.void(params[:void_reason],
                       params[:date_voided],
                       params[:voided_by])
      end
      #made restful the default due to time
      render :text => encounter.encounter_id.to_s and return
      #return encounter.id.to_s  # support non-RESTful creation of encounters
    end
  end

	def new	
		@patient = Patient.find(params[:patient_id] || session[:patient_id])
		@patient_bean = PatientService.get_patient(@patient.person)
		
		session_date = session[:datetime].to_date rescue Date.today
		if session[:datetime]
			@retrospective = true 
		else
			@retrospective = false
		end

    @procedures = []
    @proc =  GlobalProperty.find_by_property("facility.procedures").property_value.split(",") rescue []
    
    @proc.each{|proc|
      proc_concept = ConceptName.find_by_name(proc, :conditions => ["voided = 0"]).concept_id rescue nil
      @procedures << [proc, proc_concept] if !proc_concept.nil?
    }

    @diagnosis_type = params[:diagnosis_type]
        
		@diagnoses_requiring_specification = [
				'OTHER',
				'ABSCESS',
				'ALL OTHER COMMUNICABLE DISEASES',
				'ALL OTHER NON-COMMUNICABLE DISEASES',
				'ALL OTHER SURGICAL CONDITIONS',
				'GYNAECOLOGICAL DISORDERS',
				'OPPORTUNISTIC INFECTIONS',
				'OTHER HEART DISEASES',
				'OTHER SKIN CONDITION'].join(';')

		  @diagnoses_requiring_details = [
		    "ABORTION COMPLICATIONS",
		    "CANCER",
		    "CANDIDA",
		    "CHRONIC PSYCHIATRIC DISORDER",
		    "DIARRHOEA DISEASES",
		    "FRACTURE",
		    "GASTROINTESTINAL BLEED",
		    "MALARIA",
		    "MENINGITIS",
		    "MUSCULOSKELETAL PAINS",
		    "PNEUMONIA",
		    "POISONING",
		    "RENAL FAILURE",
		    "ROAD TRAFFIC ACCIDENT",
		    "SEXUALLY TRANSMITTED INFECTION",
		    "SOFT TISSUE INJURY",
		    "TRAUMATIC CONDITIONS",
		    "TUBERCULOSIS",
		    "ULCERS"].join(';')
		    
		@select_options = select_options
		@current_user_role = self.current_user_role
		@number_of_days_to_add_to_next_appointment_date = number_of_days_to_add_to_next_appointment_date(@patient, session[:datetime] || Date.today)
		@hiv_status = PatientService.patient_hiv_status(@patient)
		@hiv_test_date = PatientService.hiv_test_date(@patient.id)

    @current_encounters = @patient.encounters.find_by_date(session_date)
    @current_height = PatientService.get_patient_attribute_value(@patient, "current_height")
		@min_weight = PatientService.get_patient_attribute_value(@patient, "min_weight")
    @max_weight = PatientService.get_patient_attribute_value(@patient, "max_weight")
    @min_height = PatientService.get_patient_attribute_value(@patient, "min_height")
    @max_height = PatientService.get_patient_attribute_value(@patient, "max_height")

    @referred_to_htc = nil
     
    if (params[:encounter_type].upcase rescue '') == 'UPDATE HIV STATUS'
      @referred_to_htc = get_todays_observation_answer_for_encounter(@patient.id, "UPDATE HIV STATUS", "Refer to HTC")
    end

		@location_transferred_to = []
		if (params[:encounter_type].upcase rescue '') == 'APPOINTMENT'
		  @old_appointment = nil
		  @report_url = nil
		  @report_url =  params[:report_url]  and @old_appointment = params[:old_appointment] if !params[:report_url].nil?
		  @current_encounters.reverse.each do |enc|
		     enc.observations.each do |o|
		       @location_transferred_to << o.to_s_location_name.strip if o.to_s.include?("Transfer out to") rescue nil
		     end
		   end
		end

		@patients = nil

		if (params[:encounter_type].upcase rescue '') == "ADMIT_PATIENT"
			ipd_wards_tag = CoreService.get_global_property_value('ipd.wards.tag')
			@ipd_wards = []
			@ipd_wards = LocationTagMap.all.collect { | ltm |
				[ltm.location.name, ltm.location.name] if ltm.location_tag.name == ipd_wards_tag
			}
			@ipd_wards = @ipd_wards.compact		  
		end
		
		redirect_to "/" and return unless @patient

		redirect_to next_task(@patient) and return unless params[:encounter_type]

		redirect_to :action => :create, 'encounter[encounter_type_name]' => params[:encounter_type].upcase, 'encounter[patient_id]' => @patient.id and return if ['registration'].include?(params[:encounter_type])
		
		render :action => params[:encounter_type] if params[:encounter_type]

	end

	def current_user_role
		@role = User.current_user.user_roles.map{|r|r.role}
		return @role
	end

	def treatment
		search_string = (params[:search_string] || '').upcase
		filter_list = params[:filter_list].split(/, */) rescue []
		valid_answers = []
		unless search_string.blank?
			drugs = Drug.find(:all, :conditions => ["name LIKE ?", '%' + search_string + '%'])
			valid_answers = drugs.map {|drug| drug.name.upcase }
		end
		treatment = ConceptName.find_by_name("TREATMENT").concept
		previous_answers = Observation.find_most_common(treatment, search_string)
		suggested_answers = (previous_answers + valid_answers).reject{|answer| filter_list.include?(answer) }.uniq[0..10] 
		render :text => "<li>" + suggested_answers.join("</li><li>") + "</li>"
	end

	def locations
		search_string = (params[:search_string] || 'neno').upcase
		filter_list = params[:filter_list].split(/, */) rescue []    
		locations =  Location.find(:all, :select =>'name', :conditions => ["name LIKE ?", '%' + search_string + '%'])
		render :text => "<li>" + locations.map{|location| location.name }.join("</li><li>") + "</li>"
	end

	def observations
		# We could eventually include more here, maybe using a scope with includes
		@encounter = Encounter.find(params[:id], :include => [:observations])
		render :layout => false
	end

	def void
		@encounter = Encounter.find(params[:id])
		@encounter.void
		head :ok
	end

	def lab
		@patient = Patient.find(params[:encounter][:patient_id])
		encounter_type = params[:observations][0][:value_coded_or_text] 
		redirect_to "/encounters/new/#{encounter_type}?patient_id=#{@patient.id}"
	end

	def lab_orders
		@lab_orders = select_options['lab_orders'][params['sample']].collect{|order| order}
		render :text => '<li></li><li>' + @lab_orders.join('</li><li>') + '</li>'
	end

	def give_drugs
		@patient = Patient.find(params[:patient_id] || session[:patient_id])
		type = EncounterType.find_by_name('TREATMENT')
		session_date = session[:datetime].to_date rescue Date.today
		@prescriptions = Order.find(:all,
				         :joins => "INNER JOIN encounter e USING (encounter_id)",
				         :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
				         type.id,@patient.id,session_date])
		@historical = @patient.orders.historical.prescriptions.all
		@restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		@restricted.each do |restriction|
			@prescriptions = restriction.filter_orders(@prescriptions)
			@historical = restriction.filter_orders(@historical)
		end

		render :template => 'dashboards/treatment_dashboard', :layout => false
	end

  def select_options
    select_options = {
      'presc_time_period' => [
          ["",""],
          ["1 month", "30"],
          ["2 months", "60"],
          ["3 months", "90"],
          ["4 months", "120"],
          ["5 months", "150"],
          ["6 months", "180"],
          ["7 months", "210"],
          ["8 months", "240"]
      ],
        'hiv_status' => [
          ['',''],
          ['Negative','NEGATIVE'],
          ['Positive','POSITIVE'],
          ['Unknown','UNKNOWN']
      ],
        'art_started_answers' => [
          ['',''],
          ['Yes','YES'],
          ['No','NO'],
          ['Defaulter','DEFAULTER'],
          ['Unknown','UNKNOWN']
      ],
      'lab_orders' =>{
        "Blood" => ["Full blood count", "Malaria parasite", "Group & cross match", "Urea & Electrolytes", "CD4 count", "Resistance",
            "Viral Load", "Cryptococcal Antigen", "Lactate", "Fasting blood sugar", "Random blood sugar", "Sugar profile",
            "Liver function test", "Hepatitis test", "Sickling test", "ESR", "Culture & sensitivity", "Widal test", "ELISA",
            "ASO titre", "Rheumatoid factor", "Cholesterol", "Triglycerides", "Calcium", "Creatinine", "VDRL", "Direct Coombs",
            "Indirect Coombs", "Blood Test NOS"],
        "CSF" => ["Full CSF analysis", "Indian ink", "Protein & sugar", "White cell count", "Culture & sensitivity"],
        "Urine" => ["Urine microscopy", "Urinanalysis", "Culture & sensitivity"],
        "Aspirate" => ["Full aspirate analysis"],
        "Stool" => ["Full stool analysis", "Culture & sensitivity"],
        "Sputum-AAFB" => ["AAFB(1st)", "AAFB(2nd)", "AAFB(3rd)"],
        "Sputum-Culture" => ["Culture(1st)", "Culture(2nd)"],
        "Swab" => ["Microscopy", "Culture & sensitivity"]
      },
      'drug_related_side_effects' => [
        ['',''],
        ["Confusion", "Confusion"],
        ["Deafness", "Deafness"],
        ["Dizziness", "Dizziness"],
        ["Peripheral neuropathy","Peripheral neuropathy"],
        ["Skin itching/purpura", "Skin itching"],
        ["Visual impairment", "Visual impairment"],
        ["Vomiting", "Vomiting"],
        ["Yellow eyes", "Jaundice"],
        ["Other", "Other"]
      ],
      'admission_wards' => [
        ['',''],
        ['Ward 2A', 'Ward 2A'],
        ['Ward 3A', 'Ward 3A'],
        ['Ward 3B', 'Ward 3B'],
        ['Ward 4A', 'Ward 4A'],
        ['Other', 'Other']
      ],
      'discharge_outcomes' => [
        ['',''],
        ['Alive (Discharged home)', 'Alive'],
        ['Dead', 'Dead'],
        ['Referred (Within Queens)', 'Referred'],
        ['Transferred (Another health facility)', 'Transferred'],
        ['Absconded', 'Absconded']
      ]
    }
  end
	
	def get_todays_observation_answer_for_encounter(patient_id, encountertype_name, observation_name)
	  session_date = session[:datetime].to_date rescue Date.today
    encounter = Encounter.find(:all, :conditions=>["patient_id = ? \
                  AND encounter_type = ? AND DATE(encounter_datetime) = ? ", patient_id, \
                  EncounterType.find_by_name("#{encountertype_name}").id, session_date]).last rescue nil
        
    @date = encounter.encounter_datetime.to_date rescue nil
    observation = nil
    
    if !encounter.nil?
      for obs in encounter.observations do
        if obs.concept_id == ConceptName.find_by_name("#{observation_name}").concept_id
          observation = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}".squish
        end
      end
    end
    observation

	end

  def is_child_bearing_female(patient)
  	patient_bean = PatientService.get_patient(patient.person)
    (patient_bean.sex == 'Female' && patient_bean.age >= 9 && patient_bean.age <= 45) ? true : false
  end

   def number_of_days_to_add_to_next_appointment_date(patient, date = Date.today)
    #because a dispension/pill count can have several drugs,we pick the drug with the lowest pill count
    #and we also make sure the drugs in the pill count/Adherence encounter are the same as the one in Dispension encounter

    concept_id = ConceptName.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC').concept_id
    encounter_type = EncounterType.find_by_name('ART ADHERENCE')
    adherence = Observation.find(:all,
      :joins => 'INNER JOIN encounter USING(encounter_id)',
      :conditions =>["encounter_type = ? AND patient_id = ? AND concept_id = ? AND DATE(encounter_datetime)=?",
        encounter_type.id,patient.id,concept_id,date.to_date],:order => 'encounter_datetime DESC')
    return 0 if adherence.blank?
    concept_id = ConceptName.find_by_name('AMOUNT DISPENSED').concept_id
    encounter_type = EncounterType.find_by_name('DISPENSING')
    drug_dispensed = Observation.find(:all,
      :joins => 'INNER JOIN encounter USING(encounter_id)',
      :conditions =>["encounter_type = ? AND patient_id = ? AND concept_id = ? AND DATE(encounter_datetime)=?",
        encounter_type.id,patient.id,concept_id,date.to_date],:order => 'encounter_datetime DESC')

    #check if what was dispensed is what was counted as remaing pills
    return 0 unless (drug_dispensed.map{| d | d.value_drug } - adherence.map{|a|a.order.drug_order.drug_inventory_id}) == []

    #the folliwing block of code picks the drug with the lowest pill count
    count_drug_count = []
    (adherence).each do | adh |
      unless count_drug_count.blank?
        if adh.value_numeric < count_drug_count[1]
          count_drug_count = [adh.order.drug_order.drug_inventory_id,adh.value_numeric]
        end
      end
      count_drug_count = [adh.order.drug_order.drug_inventory_id,adh.value_numeric] if count_drug_count.blank?
    end

    #from the drug dispensed on that day,we pick the drug "plus it's daily dose" that match the drug with the lowest pill count
    equivalent_daily_dose = 1
    (drug_dispensed).each do | dispensed_drug |
      drug_order = dispensed_drug.order.drug_order
      if count_drug_count[0] == drug_order.drug_inventory_id
        equivalent_daily_dose = drug_order.equivalent_daily_dose
      end
    end
    (count_drug_count[1] / equivalent_daily_dose).to_i
  end

  def new_appointment                                                   
    #render :layout => "menu"                                                    
  end
  
  def update

    @encounter = Encounter.find(params[:encounter_id])
    ActiveRecord::Base.transaction do
      @encounter.void
    end
    
    encounter = Encounter.new(params[:encounter])
    encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank? or encounter.name == 'DIABETES TEST'
    encounter.save

       # saving  of encounter states
    if(params[:complete])
      encounter_state = EncounterState.find(encounter.encounter_id) rescue nil

      if(encounter_state) # update an existing encounter_state
        state =  params[:complete] == "true"? 1 : 0
        EncounterState.update_attributes(:encounter_id => encounter.encounter_id, :state => state)
      else # a new encounter_state
        state =  params[:complete] == "true"? 1 : 0
        EncounterState.create(:encounter_id => encounter.encounter_id, :state => state)
      end
    end

    (params[:observations] || []).each{|observation|
      # Check to see if any values are part of this observation
      # This keeps us from saving empty observations
      values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
      observation[:encounter_id] = encounter.id
      observation[:obs_datetime] = encounter.encounter_datetime ||= Time.now()
      observation[:person_id] ||= encounter.patient_id
      observation[:concept_name] ||= "OUTPATIENT DIAGNOSIS" if encounter.type.name == "OUTPATIENT DIAGNOSIS"

      # convert values from 'mmol/litre' to 'mg/declitre'
      if(observation[:measurement_unit])
        observation[:value_numeric] = observation[:value_numeric].to_f * 18 if ( observation[:measurement_unit] == "mmol/l")
        observation.delete(:measurement_unit)
      end

      if(observation[:parent_concept_name])
        concept_id = Concept.find_by_name(observation[:parent_concept_name]).id rescue nil
        observation[:obs_group_id] = Observation.find(:first, :conditions=> ['concept_id = ? AND encounter_id = ?',concept_id, encounter.id]).id rescue ""
        observation.delete(:parent_concept_name)
      end

      concept_id = Concept.find_by_name(observation[:concept_name]).id rescue nil
      obs_id = Observation.find(:first, :conditions=> ['concept_id = ? AND encounter_id = ?',concept_id, encounter.id]).id rescue nil

      extracted_value_numerics = observation[:value_numeric]
      if (extracted_value_numerics.class == Array)

        extracted_value_numerics.each do |value_numeric|
          observation[:value_numeric] = value_numeric
          Observation.create(observation)
        end
      else
        Observation.create(observation)
      end
              
    }

    @patient = Patient.find(params[:encounter][:patient_id])

    # redirect to a custom destination page 'next_url'
    #if(params[:next_url])
      redirect_to "/patients/show/#{@patient.patient_id}" and return
    #else
    #  redirect_to next_task(@patient)
    #end

  end

	def diagnoses
		search_string = (params[:search_string] || '').upcase
		filter_list = params[:filter_list].split(/, */) rescue []

		diagnosis_concept = CoreService.get_global_property_value("application_diagnosis_concept")

		if diagnosis_concept.blank?
			diagnosis_concepts = ConceptClass.find_by_name("Diagnosis").concepts rescue []
		else
			diagnosis_concepts = ConceptName.find_by_name(diagnosis_concept).concept.concept_answers.collect {|answer|
			  Concept.find(answer.answer_concept) rescue nil
			}.compact rescue []
		end

		# raise diagnosis_concepts.to_yaml    

		# TODO Need to check a global property for which concept set to limit things to
		#if (false)
		#  diagnosis_concept_set = ConceptName.find_by_name('MALAWI NATIONAL DIAGNOSIS').concept
		#  diagnosis_concepts = Concept.find(:all, :joins => :concept_sets, :conditions => ['concept_set = ?', concept_set.id], :include => [:name])
		#end  

		valid_answers = diagnosis_concepts.map{|concept| 
			name = concept.fullname rescue nil
			(!name.to_s.upcase.match(search_string.to_s.upcase).nil?) ? name : nil rescue ''
		}.compact

		@suggested_answers = valid_answers.sort.uniq.reject{|answer| filter_list.include?(answer) }.uniq[0..10]
		@suggested_answers = @suggested_answers - params[:search_filter].split(',') rescue @suggested_answers
		render :text => "<li>" + @suggested_answers.join("</li><li>") + "</li>"
	end

  def daignosis_details
				diagnosis = params[:diagnosis_string]
		   
		    @diagnoses_detail = ConceptName.find(:all, :joins => :concept, 
		      :conditions => ["concept_name.concept_id IN (?) AND voided = 0",
		      ConceptSet.find(:all, :conditions => ["concept_set IN (?)", ConceptName.find(:all, :joins => :concept, 
		              :conditions => ["voided = 0 AND name = ?", diagnosis]).collect{|nom| nom.concept_id}]).collect{|set| 
		          set.concept_id}]).collect{|term| term.name}.uniq 
		  
		    render :text => "<li></li><li>" + @diagnoses_detail.join("</li><li>") + "</li>"
  end
  
  def create_adult_influenza_entry
    create_influenza_data
  end
  
  def create_influenza_data
    # raise params.to_yaml
    
    encounter = Encounter.new(params[:encounter])
    encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank? or encounter.name == 'DIABETES TEST'
    encounter.save

    (params[:observations] || []).each{|observation|
      # Check to see if any values are part of this observation
      # This keeps us from saving empty observations
      values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
      observation[:encounter_id] = encounter.id
      observation[:obs_datetime] = encounter.encounter_datetime ||= (session[:datetime] ||= Time.now())
      observation[:person_id] ||= encounter.patient_id
      observation[:concept_name] ||= "OUTPATIENT DIAGNOSIS" if encounter.type.name == "OUTPATIENT DIAGNOSIS"

      if(observation[:measurement_unit])
        observation[:value_numeric] = observation[:value_numeric].to_f * 18 if ( observation[:measurement_unit] == "mmol/l")
        observation.delete(:measurement_unit)
      end

      if(observation[:parent_concept_name])
        concept_id = Concept.find_by_name(observation[:parent_concept_name]).id rescue nil
        observation[:obs_group_id] = Observation.find(:first, :conditions=> ['concept_id = ? AND encounter_id = ?',concept_id, encounter.id]).id rescue ""
        observation.delete(:parent_concept_name)
      end

      extracted_value_numerics = observation[:value_numeric]
      if (extracted_value_numerics.class == Array)

        extracted_value_numerics.each do |value_numeric|
          observation[:value_numeric] = value_numeric
          Observation.create(observation)
        end
      else
        Observation.create(observation)
      end
    }
    @patient = Patient.find(params[:encounter][:patient_id])

    # redirect to a custom destination page 'next_url'
    if(params[:next_url])
      redirect_to params[:next_url] and return
    else
      redirect_to next_task(@patient)
    end
    
  end

  # create_lab_entry is a method to save requested lab tests grouped by accession number
  def create_lab_entry

    encounter = Encounter.new(params[:encounter])
    
    # We need the time as well here which was not captured by session[:datetime]
    # encounter.encounter_datetime = (session[:datetime] ||= Time.now)   #session[:datetime] unless session[:datetime].blank?
    encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
    encounter.save

    identifier = PatientIdentifier.new(params[:patient_identifier])
    identifier.save

    (params[:observations] || []).each{|observation|
      # Check to see if any values are part of this observation
      # This keeps us from saving empty observations
      values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
      observation[:encounter_id] = encounter.id
      observation[:obs_datetime] = encounter.encounter_datetime ||= (session[:datetime] ||= Time.now())
      observation[:person_id] ||= encounter.patient_id

      observation[:concept_name] = "LAB TEST SERIAL NUMBER"

      value_coded_or_text = observation[:value_coded_or_text]
      observation[:value_coded_or_text] = identifier.identifier
          
      #observation[:value_text] = identifier.identifier

      o = Observation.create(observation)

      value_coded_or_text.each{|obs|

        observation[:concept_name] = "REQUESTED LAB TEST SET"
        observation[:obs_group_id] = o.obs_id
        observation[:encounter_id] = encounter.id
        observation[:obs_datetime] = encounter.encounter_datetime ||= (session[:datetime] ||= Time.now())
        observation[:person_id] ||= encounter.patient_id
        observation[:value_text] = nil
        observation[:value_coded_or_text] = obs
        Observation.create(observation)

      }
    }

    @patient = Patient.find(params[:encounter][:patient_id])
    
    # redirect to a custom destination page 'next_url'
    if encounter.type.name == "LAB ORDERS"
      print_and_redirect("/encounters/label/?encounter_id=#{encounter.id}", next_task(@patient))  if encounter.type.name == "LAB ORDERS"
      return
    elsif(params[:next_url])
      redirect_to params[:next_url] and return
    else
      redirect_to next_task(@patient)
    end
    
  end
  
  def create_influenza_recruitment
    create_influenza_data
  end

  # create_chronics is a method to save the results of an influenza
  # Chronic Conditions question set
  def create_chronics
    create_influenza_data
  end
end

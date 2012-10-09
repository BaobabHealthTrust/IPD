class EncountersController < GenericEncountersController
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
		proc =  GlobalProperty.find_by_property("facility.procedures").property_value.split(",") rescue []
    
		proc.each{|proc|
			proc_concept = ConceptName.find_by_name(proc, :conditions => ["voided = 0"]).concept_id rescue nil
			@procedures << [proc, proc_concept] if !proc_concept.nil?
		}

		@diagnosis_type = params[:diagnosis_type]
        
		@current_height = PatientService.get_patient_attribute_value(@patient, "current_height")
		@min_weight = PatientService.get_patient_attribute_value(@patient, "min_weight")
		@max_weight = PatientService.get_patient_attribute_value(@patient, "max_weight")
		@min_height = PatientService.get_patient_attribute_value(@patient, "min_height")
		@max_height = PatientService.get_patient_attribute_value(@patient, "max_height")
		@given_arvs_before = given_arvs_before(@patient)
		@current_encounters = @patient.encounters.find_by_date(session_date)
		@previous_tb_visit = previous_tb_visit(@patient.id)

		if (params[:encounter_type].upcase rescue '') == 'UPDATE HIV STATUS'
			@referred_to_htc = get_todays_observation_answer_for_encounter(@patient.id, "UPDATE HIV STATUS", "Refer to HTC")
		end

        if  ['INPATIENT_DIAGNOSIS', 'OUTPATIENT_DIAGNOSIS', 'ADMISSION_DIAGNOSIS', 'DISCHARGE_DIAGNOSIS'].include?((params[:encounter_type].upcase rescue ''))
			diagnosis_concept_set_id = ConceptName.find_by_name("Diagnoses requiring specification").concept.id
			diagnosis_concepts = Concept.find(:all, :joins => :concept_sets, :conditions => ['concept_set = ?', diagnosis_concept_set_id])	
			@diagnoses_requiring_specification = diagnosis_concepts.map{|concept| concept.fullname.upcase}.join(';')

			diagnosis_concept_set_id = ConceptName.find_by_name("Diagnoses requiring details").concept.id
			diagnosis_concepts = Concept.find(:all, :joins => :concept_sets, :conditions => ['concept_set = ?', diagnosis_concept_set_id])	
			@diagnoses_requiring_details = diagnosis_concepts.map{|concept| concept.fullname.upcase}.join(';')
        end

        if (params[:encounter_type].upcase rescue '') == 'PRESENTING_COMPLAINTS'
			complaint_concept_set_id = ConceptName.find_by_name("Presenting complaints requiring specification").concept.id
			complaint_concepts = Concept.find(:all, :joins => :concept_sets, :conditions => ['concept_set = ?', complaint_concept_set_id])
			@complaints_requiring_specification = complaint_concepts.map{|concept| concept.fullname.upcase}.join(';')

			complaint_concept_set_id = ConceptName.find_by_name("Presenting complaints requiring details").concept.id
			complaint_concepts = Concept.find(:all, :joins => :concept_sets, :conditions => ['concept_set = ?', complaint_concept_set_id])	
			@complaints_requiring_details = complaint_concepts.map{|concept| concept.fullname.upcase}.join(';')
        end

		@select_options = select_options
		@months_since_last_hiv_test = PatientService.months_since_last_hiv_test(@patient.id)
		@current_user_role = self.current_user_role
		@recent_lab_results = patient_recent_lab_results(@patient.id)
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
	
        
		if (params[:encounter_type].upcase rescue '') == 'DISCHARGE_PATIENT'
			@discharge_outcomes = [
				['',''],
				['Alive (Discharged home)', 'Alive'],
				['Dead', 'Dead'],
				['Referred (Within facility)', 'Referred'],
				['Transferred (Another health facility)', 'Transferred'],
				['Absconded', 'Absconded'],
				['Discharged (Home based care)', 'Home based care']]
		end
		
		if (params[:encounter_type].upcase rescue '') == "ADMIT_PATIENT"
			
			ipd_wards_tag = CoreService.get_global_property_value('ipd.wards.tag')
			@ipd_wards = []
			@ipd_wards = LocationTagMap.all.collect { | ltm |
				[ltm.location.name] if ltm.location_tag.name == ipd_wards_tag
			}
			@ipd_wards = @ipd_wards.compact.sort		  
		end
		
		redirect_to "/" and return unless @patient

		redirect_to next_task(@patient) and return unless params[:encounter_type]

		redirect_to :action => :create, 'encounter[encounter_type_name]' => params[:encounter_type].upcase, 'encounter[patient_id]' => @patient.id and return if ['registration'].include?(params[:encounter_type])

		if params[:encounter_type].upcase == 'ADMISSION DIAGNOSIS' || params[:encounter_type].upcase == 'DISCHARGE DIAGNOSIS' || params[:encounter_type].upcase == 'OUTPATIENT_DIAGNOSIS'
			if !is_encounter_available(@patient, 'VITALS', session_date)
        if @patient_bean.age <= 14
          session[:original_encounter] = params[:encounter_type]
          params[:encounter_type] = 'vitals'
        end
			end
		end
		
		if (params[:encounter_type].upcase rescue '') == 'HIV_STAGING' and  (CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true" rescue false)
			render :template => 'encounters/extended_hiv_staging'
		else
			render :action => params[:encounter_type] if params[:encounter_type]
		end
		
	end

	def select_options
		select_options = {
			'reason_for_tb_clinic_visit' => [
				['',''],
				['Clinical review (Children, Smear-, HIV+)','CLINICAL REVIEW'],
				['Smear Positive (HIV-)','SMEAR POSITIVE'],
				['X-ray result interpretation','X-RAY RESULT INTERPRETATION']
			],
			'tb_clinic_visit_type' => [
				['',''],
				['Lab analysis','Lab follow-up'],
				['Follow-up','Follow-up'],
				['Clinical review (Clinician visit)','Clinical review']
			],
			'family_planning_methods' => [
				['',''],
				['Oral contraceptive pills', 'ORAL CONTRACEPTIVE PILLS'],
				['Depo-Provera', 'DEPO-PROVERA'],
				['IUD-Intrauterine device/loop', 'INTRAUTERINE CONTRACEPTION'],
				['Contraceptive implant', 'CONTRACEPTIVE IMPLANT'],
				['Male condoms', 'MALE CONDOMS'],
				['Female condoms', 'FEMALE CONDOMS'],
				['Rhythm method', 'RYTHM METHOD'],
				['Withdrawal', 'WITHDRAWAL'],
				['Abstinence', 'ABSTINENCE'],
				['Tubal ligation', 'TUBAL LIGATION'],
				['Vasectomy', 'VASECTOMY']
			],
			'male_family_planning_methods' => [
			['',''],
				['Male condoms', 'MALE CONDOMS'],
				['Withdrawal', 'WITHDRAWAL'],
				['Rhythm method', 'RYTHM METHOD'],
				['Abstinence', 'ABSTINENCE'],
				['Vasectomy', 'VASECTOMY'],
				['Other','OTHER']
			],
			'female_family_planning_methods' => [
			['',''],
				['Oral contraceptive pills', 'ORAL CONTRACEPTIVE PILLS'],
				['Depo-Provera', 'DEPO-PROVERA'],
				['IUD-Intrauterine device/loop', 'INTRAUTERINE CONTRACEPTION'],
				['Contraceptive implant', 'CONTRACEPTIVE IMPLANT'],
				['Female condoms', 'FEMALE CONDOMS'],
				['Withdrawal', 'WITHDRAWAL'],
				['Rhythm method', 'RYTHM METHOD'],
				['Abstinence', 'ABSTINENCE'],
				['Tubal ligation', 'TUBAL LIGATION'],
				['Emergency contraception', 'EMERGENCY CONTRACEPTION'],
				['Other','OTHER']
			],
			'drug_list' => [
			['',''],
				["Rifampicin Isoniazid Pyrazinamide and Ethambutol", "RHEZ (RIF, INH, Ethambutol and Pyrazinamide tab)"],
				["Rifampicin Isoniazid and Ethambutol", "RHE (Rifampicin Isoniazid and Ethambutol -1-1-mg t"],
				["Rifampicin and Isoniazid", "RH (Rifampin and Isoniazid tablet)"],
				["Stavudine Lamivudine and Nevirapine", "D4T+3TC+NVP"],
				["Stavudine Lamivudine + Stavudine Lamivudine and Nevirapine", "D4T+3TC/D4T+3TC+NVP"],
				["Zidovudine Lamivudine and Nevirapine", "AZT+3TC+NVP"]
			],
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
			'continue_treatment' => [
				["",""],
				["Yes", "YES"],
				["DHO DOT site","DHO DOT SITE"],
				["Transfer Out", "TRANSFER OUT"]
			],
			'hiv_status' => [
				['',''],
				['Negative','NEGATIVE'],
				['Positive','POSITIVE'],
				['Unknown','UNKNOWN']
			],
			'who_stage1' => [
				['',''],
				['Asymptomatic','ASYMPTOMATIC'],
				['Persistent generalised lymphadenopathy','PERSISTENT GENERALISED LYMPHADENOPATHY'],
				['Unspecified stage 1 condition','UNSPECIFIED STAGE 1 CONDITION']
			],
			'who_stage2' => [
				['',''],
				['Unspecified stage 2 condition','UNSPECIFIED STAGE 2 CONDITION'],
				['Angular cheilitis','ANGULAR CHEILITIS'],
				['Popular pruritic eruptions / Fungal nail infections','POPULAR PRURITIC ERUPTIONS / FUNGAL NAIL INFECTIONS']
			],
			'who_stage3' => [
				['',''],
				['Oral candidiasis','ORAL CANDIDIASIS'],
				['Oral hairly leukoplakia','ORAL HAIRLY LEUKOPLAKIA'],
				['Pulmonary tuberculosis','PULMONARY TUBERCULOSIS'],
				['Unspecified stage 3 condition','UNSPECIFIED STAGE 3 CONDITION']
			],
			'who_stage4' => [
				['',''],
				['Toxaplasmosis of the brain','TOXAPLASMOSIS OF THE BRAIN'],
				["Kaposi's Sarcoma","KAPOSI'S SARCOMA"],
				['Unspecified stage 4 condition','UNSPECIFIED STAGE 4 CONDITION'],
				['HIV encephalopathy','HIV ENCEPHALOPATHY']
			],
			'tb_xray_interpretation' => [
				['',''],
				['Consistent of TB','Consistent of TB'],
				['Not Consistent of TB','Not Consistent of TB']
			],
			'lab_orders' => {
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
			'tb_symptoms_short' => [
				['',''],
				["Bloody cough", "Hemoptysis"],
				["Chest pain", "Chest pain"],
				["Cough", "Cough lasting more than three weeks"],
				["Fatigue", "Fatigue"],
				["Fever", "Relapsing fever"],
				["Loss of appetite", "Loss of appetite"],
				["Night sweats","Night sweats"],
				["Shortness of breath", "Shortness of breath"],
				["Weight loss", "Weight loss"],
				["Other", "Other"]
			],
			'tb_symptoms_all' => [
				['',''],
				["Bloody cough", "Hemoptysis"],
				["Bronchial breathing", "Bronchial breathing"],
				["Crackles", "Crackles"],
				["Cough", "Cough lasting more than three weeks"],
				["Failure to thrive", "Failure to thrive"],
				["Fatigue", "Fatigue"],
				["Fever", "Relapsing fever"],
				["Loss of appetite", "Loss of appetite"],
				["Meningitis", "Meningitis"],
				["Night sweats","Night sweats"],
				["Peripheral neuropathy", "Peripheral neuropathy"],
				["Shortness of breath", "Shortness of breath"],
				["Weight loss", "Weight loss"],
				["Other", "Other"]
			],
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
			'tb_patient_categories' => [
				['',''],
				["New", "New patient"],
				["Failure", "Failed - TB"],
				["Relapse", "Relapse MDR-TB patient"],
				["Treatment after default", "Treatment after default MDR-TB patient"],
				["Other", "Other"]
			],
			'duration_of_current_cough' => [
				['',''],
				["Less than 1 week", "Less than one week"],
				["1 Week", "1 week"],
				["2 Weeks", "2 weeks"],
				["3 Weeks", "3 weeks"],
				["4 Weeks", "4 weeks"],
				["More than 4 Weeks", "More than 4 weeks"],
				["Unknown", "Unknown"]
			],
			'eptb_classification'=> [
				['',''],
				['Pulmonary effusion', 'Pulmonary effusion'],
				['Lymphadenopathy', 'Lymphadenopathy'],
				['Pericardial effusion', 'Pericardial effusion'],
				['Ascites', 'Ascites'],
				['Spinal disease', 'Spinal disease'],
				['Meningitis','Meningitis'],
				['Other', 'Other']
			],
			'tb_types' => [
				['',''],
				['Susceptible', 'Susceptible to tuberculosis drug'],
				['Multi-drug resistant (MDR)', 'Multi-drug resistant tuberculosis'],
				['Extreme drug resistant (XDR)', 'Extreme drug resistant tuberculosis']
			],
			'tb_classification' => [
				['',''],
				['Pulmonary tuberculosis (PTB)', 'Pulmonary tuberculosis'],
				['Extrapulmonary tuberculosis (EPTB)', 'Extrapulmonary tuberculosis (EPTB)']
			],
			'source_of_referral' => [
				['',''],
				['Walk in', 'Walk in'],
				['Healthy Facility', 'Healthy Facility'],
				['Index Patient', 'Index Patient'],
				['HTC', 'HTC clinic'],
				['ART', 'ART'],
				['PMTCT', 'PMTCT'],
				['Private practitioner', 'Private practitioner'],
				['Sputum collection point', 'Sputum collection point'],
				['Other','Other']
			]
		}
	end

	def create_adult_influenza_entry
		create_influenza_data
	end
  
	def create_influenza_data
		# raise params.to_yaml

		encounter = Encounter.new(params[:encounter])
		encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank? or encounter.name == 'DIABETES TEST'
		encounter.save

		(params[:observations] || []).each{ | observation |
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

	def create_influenza_recruitment
		create_influenza_data
	end
  
	# create_chronics is a method to save the results of an influenza
	# Chronic Conditions question set
	def create_chronics
		create_influenza_data
	end 

	def presenting_complaints
		search_string = (params[:search_string] || '').upcase
		filter_list = params[:filter_list].split(/, */) rescue []
		
		presenting_complaint = ConceptName.find_by_name("PRESENTING COMPLAINT").concept
		

		complaint_set = CoreService.get_global_property_value("application_presenting_complaint")
		complaint_set = "PRESENTING COMPLAINT" if complaint_set.blank?
		complaint_concept_set = ConceptName.find_by_name(complaint_set).concept
		complaint_concepts = Concept.find(:all, :joins => :concept_sets, :conditions => ['concept_set = ?', complaint_concept_set.id])

		valid_answers = complaint_concepts.map{|concept| 
			name = concept.fullname rescue nil
			name.upcase.include?(search_string) ? name : nil rescue nil
		}.compact

		previous_answers = []

		# TODO Need to check global property to find out if we want previous answers or not (right now we)
		previous_answers = Observation.find_most_common(presenting_complaint, search_string)

		@suggested_answers = (previous_answers + valid_answers.sort!).reject{|answer| filter_list.include?(answer) }.uniq[0..10] 
		@suggested_answers = @suggested_answers - params[:search_filter].split(',') rescue @suggested_answers
		render :text => "<li></li>" + "<li>" + @suggested_answers.join("</li><li>") + "</li>"
	end

	#added this to ensure that we are able to get the detailed diagnosis set
	def diagnosis_details
		concept_name = params[:diagnosis_string]
		options = concept_set(concept_name).flatten.uniq
		render :text => "<li></li><li>" + options.join("</li><li>") + "</li>"
	end

	#added this to ensure that we are able to get the detailed diagnosis set
	def concept_options
		concept_name = params[:search_string]
		options = concept_set(concept_name).flatten.uniq
		  
		render :text => "<li></li><li>" + options.join("</li><li>") + "</li>"
	end
  
end

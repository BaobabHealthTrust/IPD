class ReportController < GenericReportController

  def adt_generic_report_printable
    start_date = params[:start_date].to_date
    end_date = params[:end_date].to_date
    @location_name = Location.current_health_center.name rescue nil
    @logo = CoreService.get_global_property_value('logo').to_s rescue nil
    @start_date = start_date
    @end_date = end_date
    encounter_type = EncounterType.find_by_name("ADMIT PATIENT")

    @total_admissions = Encounter.find(:all, :conditions => ["DATE(encounter_datetime) >= ? AND
      DATE(encounter_datetime) <= ? AND encounter_type =?",start_date.to_date, end_date.to_date, encounter_type.id])
    @total_admissions_ids = @total_admissions.map(&:patient_id)
    @total_admissions_males = Encounter.find(:all, :joins => [:patient => :person],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND gender =?",start_date.to_date, end_date.to_date, encounter_type.id, "M"])
    @total_admissions_males_ids = @total_admissions_males.map(&:patient_id)
    @total_admissions_females = Encounter.find(:all, :joins => [:patient => :person],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND gender =?",start_date.to_date, end_date.to_date, encounter_type.id, "F"])
    @total_admissions_females_ids = @total_admissions_females.map(&:patient_id)
    @total_admissions_infants = Encounter.find(:all, :joins => [:patient => :person],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND DATEDIFF(NOW(), person.birthdate)/365 <= 2",start_date.to_date, end_date.to_date, encounter_type.id])
    @total_admissions_infants_ids = @total_admissions_infants.map(&:patient_id) rescue nil
    @total_admissions_children = Encounter.find(:all, :joins => [:patient => :person],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND DATEDIFF(NOW(), person.birthdate)/365 > ? AND
      DATEDIFF(NOW(), person.birthdate)/365 <= ?",start_date.to_date, end_date.to_date, encounter_type.id, 2, 14])
    @total_admissions_children_ids = @total_admissions_children.map(&:patient_id) rescue nil
    @total_admissions_adults = Encounter.find(:all, :joins => [:patient => :person],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND DATEDIFF(NOW(), person.birthdate)/365 > 14",start_date.to_date, end_date.to_date, encounter_type.id])
      @total_admissions_adults_ids = @total_admissions_adults.map(&:patient_id) rescue nil
    #available_wards = CoreService.get_global_property_value('kch_wards').split(",") rescue nil
    available_wards = Ward.find(:all, :conditions => ["voided =?",0]).collect{|ward|[ward.name.squish]}
    concept_id = Concept.find_by_name('ADMIT TO WARD').id
    @admission_by_ward = {}
    available_wards.each do |ward|
      obs = Observation.find(:all, :conditions => ["DATE(obs_datetime) >= ? AND DATE(obs_datetime) <=? AND
          concept_id =? AND value_text =?", start_date, end_date, concept_id, ward])
      next if obs.blank?
      @admission_by_ward[ward] = {}
      @admission_by_ward[ward]['count'] = obs.count
      @admission_by_ward[ward]['patient_ids'] = obs.map(&:person_id)
    end

    @admission_diagnoses = {}
    admission_diagnosis_enc = EncounterType.find_by_name('ADMISSION DIAGNOSIS')
    diagnosis_concept_id = Concept.find_by_name('PRIMARY DIAGNOSIS').id
    admission_diagnosis_encs = Encounter.find(:all, :conditions => ["DATE(encounter_datetime) >= ? AND
  DATE(encounter_datetime) <= ? AND
      encounter_type =?", start_date, end_date, admission_diagnosis_enc.id])


    admission_diagnosis_encs.each do |enc|
     observations = enc.observations.find(:all, :conditions => ["concept_id =? ", diagnosis_concept_id])
       observations.each do |obs|
         if (@admission_diagnoses[obs.answer_string.squish].blank?)
          @admission_diagnoses[obs.answer_string.squish] = {}
          @admission_diagnoses[obs.answer_string.squish]["count"] = 0
          @admission_diagnoses[obs.answer_string.squish]["patient_ids"] = []
         end

         unless (@admission_diagnoses[obs.answer_string.squish].blank?)
          @admission_diagnoses[obs.answer_string.squish]["count"]+=1
          @admission_diagnoses[obs.answer_string.squish]["patient_ids"] << obs.person_id
         end
       end
    end
    @admission_diagnoses = @admission_diagnoses.sort_by{|key, value|value["count"]}.reverse

    @discharge_diagnoses = {}
    discharge_diagnosis_enc = EncounterType.find_by_name('DISCHARGE DIAGNOSIS')
     discharge_diagnosis_encs = Encounter.find(:all, :conditions => ["DATE(encounter_datetime) >= ? AND
      DATE(encounter_datetime) <= ? AND
      encounter_type =?", start_date, end_date, discharge_diagnosis_enc.id])
    discharge_diagnosis_encs.each do |enc|
     observations = enc.observations.find(:all, :conditions => ["concept_id =? ", diagnosis_concept_id])
       observations.each do |obs|
         if (@discharge_diagnoses[obs.answer_string.squish].blank?)
          @discharge_diagnoses[obs.answer_string.squish] = {}
          @discharge_diagnoses[obs.answer_string.squish]["count"] = 0
          @discharge_diagnoses[obs.answer_string.squish]["patient_ids"] = []
         end

         unless (@discharge_diagnoses[obs.answer_string.squish].blank?)
          @discharge_diagnoses[obs.answer_string.squish]["count"]+=1
          @discharge_diagnoses[obs.answer_string.squish]["patient_ids"] << obs.person_id
         end
       end
    end
    @discharge_diagnoses = @discharge_diagnoses.sort_by{|key, value|value["count"]}.reverse

=begin
    Building a hash that looks like the one below to find admission diagnosis by ward
    data = {22=>{:ward=>"1A", :diagnosis=>"malaria"},
    20=>{:ward=>"2A", :diagnosis=>"malaria"}, 21=>{:ward=>"1A", :diagnosis=>"malaria"}}
=end
    admission_diagnosis_by_ward = {}
    admit_to_ward_concept = Concept.find_by_name("ADMIT TO WARD")
    patient_admission_enc_ids = admission_diagnosis_encs.map(&:patient_id)
    patient_admission_enc_ids.each do |patient_id|
     admission_obs  = Observation.find(:last, :conditions => ["person_id =? AND concept_id =?", patient_id, admit_to_ward_concept.id]) rescue nil
     ward_admitted  = admission_obs.answer_string.squish rescue nil
     admission_diagnosis_enc = Encounter.find(:last, :conditions => ["patient_id =? AND DATE(encounter_datetime) >= ? \
          AND DATE(encounter_datetime) <= ? AND
          encounter_type =?", patient_id, start_date, end_date, EncounterType.find_by_name('ADMISSION DIAGNOSIS').id])
     admission_diagnosis_obs = admission_diagnosis_enc.observations.find(:last, :conditions => ["concept_id =? ", diagnosis_concept_id]) rescue nil
     diagnosis = admission_diagnosis_obs.answer_string.squish rescue nil
     next if diagnosis.blank?
     next if ward_admitted.blank?
     admission_diagnosis_by_ward[patient_id] = {}
     admission_diagnosis_by_ward[patient_id][:ward] = ward_admitted
     admission_diagnosis_by_ward[patient_id][:diagnosis] =  diagnosis
    end
    @total_admission_diagnosis_by_ward = Hash.new
    @ward_patients_diagnosis = {}
    admission_diagnosis_by_ward.each do |key, value|
      #==============================================================
      if (@ward_patients_diagnosis[value[:ward]].blank?)
        @ward_patients_diagnosis[value[:ward]] = {}
      end
      if (@ward_patients_diagnosis[value[:ward]][value[:diagnosis]].blank?)
        @ward_patients_diagnosis[value[:ward]][value[:diagnosis]] = ""
        @ward_patients_diagnosis[value[:ward]][value[:diagnosis]] +=key.to_s
      else
        @ward_patients_diagnosis[value[:ward]][value[:diagnosis]] +=", " + key.to_s
      end

      #=============================================================
      if (@total_admission_diagnosis_by_ward[value[:ward]].blank?)
        @total_admission_diagnosis_by_ward[value[:ward]] = {}
        @total_admission_diagnosis_by_ward[value[:ward]][value[:diagnosis]] = 0
      end
      unless (@total_admission_diagnosis_by_ward[value[:ward]].blank?)
        unless (@total_admission_diagnosis_by_ward[value[:ward]][value[:diagnosis]].blank?)
          @total_admission_diagnosis_by_ward[value[:ward]][value[:diagnosis]] += 1
        else
          @total_admission_diagnosis_by_ward[value[:ward]][value[:diagnosis]] = 1
        end
      end
    end
    #raise @ward_patients_diagnosis.inspect
    ############################################################################################


    discharge_diagnosis_by_ward = {}
    primary_diagnosis_concept = Concept.find_by_name("PRIMARY DIAGNOSIS")
    patient_discharge_enc_ids =  discharge_diagnosis_encs.map(&:patient_id)
    patient_discharge_enc_ids.each do |patient_id|
     admission_obs  = Observation.find(:last, :conditions => ["person_id =? AND concept_id =?", patient_id, Concept.find_by_name('ADMIT TO WARD').id]) rescue nil
     ward_admitted  = admission_obs.answer_string.squish rescue nil
     discharge_diagnosis_enc = Encounter.find(:last, :conditions => ["patient_id =? AND DATE(encounter_datetime) >= ? \
          AND DATE(encounter_datetime) <= ? AND
          encounter_type =?", patient_id, start_date, end_date, EncounterType.find_by_name('DISCHARGE DIAGNOSIS').id])
     discharge_diagnosis_obs = discharge_diagnosis_enc.observations.find(:last, :conditions => ["concept_id =? ", primary_diagnosis_concept.id]) rescue nil
     diagnosis = discharge_diagnosis_obs.answer_string.squish rescue nil
     next if diagnosis.blank?
     next if ward_admitted.blank?
     discharge_diagnosis_by_ward[patient_id] = {}
     discharge_diagnosis_by_ward[patient_id][:ward] = ward_admitted
     discharge_diagnosis_by_ward[patient_id][:diagnosis] =  diagnosis
    end

    @total_discharge_diagnosis_by_ward = Hash.new
    @ward_patients_discharge_diagnosis = {}
    discharge_diagnosis_by_ward.each do |key, value|

      #==============================================================
      if (@ward_patients_discharge_diagnosis[value[:ward]].blank?)
        @ward_patients_discharge_diagnosis[value[:ward]] = {}
      end
      if (@ward_patients_discharge_diagnosis[value[:ward]][value[:diagnosis]].blank?)
        @ward_patients_discharge_diagnosis[value[:ward]][value[:diagnosis]] = ""
        @ward_patients_discharge_diagnosis[value[:ward]][value[:diagnosis]] +=key.to_s
      else
        @ward_patients_discharge_diagnosis[value[:ward]][value[:diagnosis]] +=", " + key.to_s
      end

      #=============================================================


      if (@total_discharge_diagnosis_by_ward[value[:ward]].blank?)
        @total_discharge_diagnosis_by_ward[value[:ward]] = {}
        @total_discharge_diagnosis_by_ward[value[:ward]][value[:diagnosis]] = 0
      end
      unless (@total_discharge_diagnosis_by_ward[value[:ward]].blank?)
        unless (@total_discharge_diagnosis_by_ward[value[:ward]][value[:diagnosis]].blank?)
          @total_discharge_diagnosis_by_ward[value[:ward]][value[:diagnosis]] += 1
        else
          @total_discharge_diagnosis_by_ward[value[:ward]][value[:diagnosis]] = 1
        end
      end
    end



    #############################################################################################
    @patient_states = {}
    patient_states = PatientState.find(:all, :conditions => ["start_date >= ?", start_date])
    patient_states.each do |state|
      fullname = state.program_workflow_state.concept.fullname
      next unless fullname.match(/died|Discharged|Patient transferred|Absconded/i)
      if (@patient_states[fullname].blank?)
        @patient_states[fullname] = {}
        @patient_states[fullname]["count"] = 0
        @patient_states[fullname]["patient_ids"] = []
      end

      unless (@patient_states[fullname].blank?)
        @patient_states[fullname]["count"]+=1
        @patient_states[fullname]["patient_ids"] << state.patient_program.patient_id
      end
    end
    @patient_states = @patient_states.sort_by{|key, value|value["count"]}.reverse

    ##########################################################################################
    bed_sum = 0
    all_beds = Ward.find(:all, :conditions => ["voided =?",0]).collect{|ward|ward.bed_number}
    all_beds.each do |bed|
      bed_sum += bed.to_i.abs
    end
    @bed_occupacy_ratio = @total_admissions.count/bed_sum rescue 0

    total_discharges = Encounter.find(:all, :conditions => ["DATE(encounter_datetime) >= ? AND
      DATE(encounter_datetime) <= ? AND encounter_type =?",start_date.to_date, end_date.to_date,\
        EncounterType.find_by_name('DISCHARGE PATIENT').id])
    @turn_over_rate = total_discharges.count/bed_sum rescue 0
    @total_died = {}
    patient_states.each do |state|
      fullname = state.program_workflow_state.concept.fullname
      next unless fullname.match(/died/i)
      if (@total_died[fullname].blank?)
        @total_died[fullname] = {}
        @total_died[fullname]["count"] = 0
      end

      unless (@total_died[fullname].blank?)
        @total_died[fullname]["count"]+=1
      end
    end
    ##############################################################################################
    program_id = Program.find_by_name('IPD PROGRAM').id
    admission_days = []
    total_admission_days = 0
    @total_admissions_ids.uniq.each do |patient_id|
      patient = Patient.find(patient_id)
      ipd_programs = patient.patient_programs.select{|p| p.program_id == program_id }
      ipd_programs.each do |program|
        start_date = program.date_enrolled.to_date
        if (program.closed?)
          end_date = program.date_completed.to_date
        else
          end_date = Date.today
        end
        days_in_hospital = (end_date - start_date).to_i
        #raise days_in_hospital.inspect
        admission_days << days_in_hospital.abs
      end
    end
    admission_days.each do |days|
      total_admission_days+=days
    end
    @average_length_of_stay = total_admission_days/@total_admissions_ids.count rescue 0
    ##############################################################################################
    render :layout => false
  end

  def adt_report_by_ward_printable

  @location_name = Location.current_health_center.name rescue nil
	@logo = CoreService.get_global_property_value('logo').to_s rescue nil
	start_date = params[:start_date].to_date
	end_date = params[:end_date].to_date
	ward = params[:ward]
	@start_date = start_date
	@end_date = end_date
  @ward = ward
	encounter_type = EncounterType.find_by_name("ADMIT PATIENT")

    @total_admissions = Encounter.find(:all, :joins => [:observations],:conditions => ["DATE(encounter_datetime) >= ? AND
      DATE(encounter_datetime) <= ? AND encounter_type =? AND value_text =?",\
      start_date.to_date, end_date.to_date, encounter_type.id, ward])
	@total_admissions_ids = @total_admissions.map(&:patient_id)

	@total_admissions_males = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND gender =? AND value_text =?",start_date.to_date, end_date.to_date, encounter_type.id, "M", ward])
   @total_admissions_males_ids = @total_admissions_males.map(&:patient_id)

   @total_admissions_females = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND gender =? AND value_text =?",start_date.to_date, end_date.to_date, encounter_type.id, "F", ward])
   @total_admissions_females_ids = @total_admissions_females.map(&:patient_id)

   @total_admissions_infants = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND DATEDIFF(NOW(), person.birthdate)/365 <= 2  AND value_text =?",\
      start_date.to_date, end_date.to_date, encounter_type.id, ward])
   @total_admissions_infants_ids = @total_admissions_infants.map(&:patient_id) rescue nil

  @total_admissions_children = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND DATEDIFF(NOW(), person.birthdate)/365 > ? AND
      DATEDIFF(NOW(), person.birthdate)/365 <= ? AND value_text =?",start_date.to_date, end_date.to_date, encounter_type.id, 2, 14, ward])
  @total_admissions_children_ids = @total_admissions_children.map(&:patient_id) rescue nil
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  @total_admissions_adults = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND DATEDIFF(NOW(), person.birthdate)/365 > 14  AND value_text =?",start_date.to_date, end_date.to_date, encounter_type.id, ward])
  @total_admissions_adults_ids = @total_admissions_adults.map(&:patient_id) rescue nil

  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  @admission_diagnoses = {}
    admission_diagnosis_enc = EncounterType.find_by_name('ADMISSION DIAGNOSIS')
    diagnosis_concept_id = Concept.find_by_name('PRIMARY DIAGNOSIS').id
    admission_diagnosis_encs = Encounter.find(:all, :conditions => ["DATE(encounter_datetime) >= ? AND
  DATE(encounter_datetime) <= ? AND
      encounter_type =?", start_date, end_date, admission_diagnosis_enc.id])


    admission_diagnosis_encs.each do |enc|
     observations = enc.observations.find(:all, :conditions => ["concept_id =? AND person_id IN (?)", diagnosis_concept_id, @total_admissions_ids])
       observations.each do |obs|
         if (@admission_diagnoses[obs.answer_string.squish].blank?)
          @admission_diagnoses[obs.answer_string.squish] = {}
          @admission_diagnoses[obs.answer_string.squish]["count"] = 0
          @admission_diagnoses[obs.answer_string.squish]["patient_ids"] = []
         end

         unless (@admission_diagnoses[obs.answer_string.squish].blank?)
          @admission_diagnoses[obs.answer_string.squish]["count"]+=1
          @admission_diagnoses[obs.answer_string.squish]["patient_ids"] << obs.person_id
         end
       end
    end
    @admission_diagnoses = @admission_diagnoses.sort_by{|key, value|value["count"]}.reverse
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  @discharge_diagnoses = {}
    discharge_diagnosis_enc = EncounterType.find_by_name('DISCHARGE DIAGNOSIS')
     discharge_diagnosis_encs = Encounter.find(:all, :conditions => ["DATE(encounter_datetime) >= ? AND
      DATE(encounter_datetime) <= ? AND
      encounter_type =?", start_date, end_date, discharge_diagnosis_enc.id])
    discharge_diagnosis_encs.each do |enc|
     observations = enc.observations.find(:all, :conditions => ["concept_id =? AND person_id IN (?)", diagnosis_concept_id, @total_admissions_ids])
       observations.each do |obs|
         if (@discharge_diagnoses[obs.answer_string.squish].blank?)
          @discharge_diagnoses[obs.answer_string.squish] = {}
          @discharge_diagnoses[obs.answer_string.squish]["count"] = 0
          @discharge_diagnoses[obs.answer_string.squish]["patient_ids"] = []
         end

         unless (@discharge_diagnoses[obs.answer_string.squish].blank?)
          @discharge_diagnoses[obs.answer_string.squish]["count"]+=1
          @discharge_diagnoses[obs.answer_string.squish]["patient_ids"] << obs.person_id
         end
       end
    end
    @discharge_diagnoses = @discharge_diagnoses.sort_by{|key, value|value["count"]}.reverse
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    bed_size = Ward.find(:first, :conditions => ["name =? AND voided =?",ward, 0]).bed_number.to_i rescue 0
    total_discharges = Encounter.find(:all, :conditions => ["DATE(encounter_datetime) >= ? AND
      DATE(encounter_datetime) <= ? AND
      encounter_type =? AND patient_id IN (?)", start_date, end_date, discharge_diagnosis_enc.id, @total_admissions_ids])

    @turn_over_rate = total_discharges.count/bed_size rescue 0
    @bed_occupacy_ratio = @total_admissions.count/bed_size rescue 0
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  @patient_states = {}
    patient_states = PatientState.find(:all, :joins => [:patient_program],:conditions => ["patient_id IN (?) AND
    start_date >= ?", @total_admissions_ids, start_date])
    patient_states.each do |state|
      fullname = state.program_workflow_state.concept.fullname
      next unless fullname.match(/died|Discharged|Patient transferred|Absconded/i)
      if (@patient_states[fullname].blank?)
        @patient_states[fullname] = {}
        @patient_states[fullname]["count"] = 0
        @patient_states[fullname]["patient_ids"] = []
      end

      unless (@patient_states[fullname].blank?)
        @patient_states[fullname]["count"]+=1
        @patient_states[fullname]["patient_ids"] << state.patient_program.patient_id
      end
    end
    @patient_states = @patient_states.sort_by{|key, value|value["count"]}.reverse
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
   program_id = Program.find_by_name('IPD PROGRAM').id
    admission_days = []
    total_admission_days = 0
    @total_admissions_ids.uniq.each do |patient_id|
      patient = Patient.find(patient_id)
      ipd_programs = patient.patient_programs.select{|p| p.program_id == program_id }
      ipd_programs.each do |program|
        start_date = program.date_enrolled.to_date
        if (program.closed?)
          end_date = program.date_completed.to_date
        else
          end_date = Date.today
        end
        days_in_hospital = (end_date - start_date).to_i
        admission_days << days_in_hospital.abs
      end
    end
    admission_days.each do |days|
      total_admission_days+=days
    end
    @average_length_of_stay = total_admission_days/@total_admissions_ids.count rescue 0

  render :layout => false
  end

  def shift_report_printable
      @logo = CoreService.get_global_property_value('logo')
      @shift_type = params[:shift_type]
      @shift_date = params[:shift_date]
      @current_location_name = Location.current_health_center.name rescue nil
      ward = params[:ward]
      @ward = ward

     if params[:start_time] == ""
			 if @shift_type == "day"
				 @start_time = Time.parse(@shift_date + " 7:30:00")
				 @end_time = Time.parse(@shift_date + " 16:59:59")
       end

			 if @shift_type == "night"
				 @start_time = Time.parse(@shift_date + " 17:00:00")
				 @end_time= (Time.parse(@shift_date + " 7:30:00")).tomorrow
       end

       if @shift_type == "24_hour"
				 @start_time = Time.parse(@shift_date + " 17:00:00")
				 @end_time= (Time.parse(@shift_date + " 7:29:59")).tomorrow
			 end

      else
					@start_time = Time.parse(@shift_date + " " + params[:start_time])
					@end_time = Time.parse(@shift_date + " " + params[:end_time])
     end

     start_date = @start_time
     end_date = @end_time
 #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    encounter_type = EncounterType.find_by_name("ADMIT PATIENT")

    @total_admissions = Encounter.find(:all, :joins => [:observations],:conditions => ["encounter_datetime >= ? AND
      encounter_datetime <= ? AND encounter_type =? AND value_text =?",\
      start_date, end_date, encounter_type.id, ward])
    @total_admissions_ids = @total_admissions.map(&:patient_id)

    @total_admissions_males = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ? AND
      encounter_type =? AND gender =? AND value_text =?",start_date, end_date, encounter_type.id, "M", ward])
    @total_admissions_males_ids = @total_admissions_males.map(&:patient_id)

    @total_admissions_females = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ? AND
      encounter_type =? AND gender =? AND value_text =?",start_date, end_date, encounter_type.id, "F", ward])
    @total_admissions_females_ids = @total_admissions_females.map(&:patient_id)

    @total_admissions_infants = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ? AND
      encounter_type =? AND DATEDIFF(NOW(), person.birthdate)/365 <= 2  AND value_text =?",\
      start_date, end_date, encounter_type.id, ward])
    @total_admissions_infants_ids = @total_admissions_infants.map(&:patient_id) rescue nil

    @total_admissions_children = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ? AND
      encounter_type =? AND DATEDIFF(NOW(), person.birthdate)/365 > ? AND
      DATEDIFF(NOW(), person.birthdate)/365 <= ? AND value_text =?",start_date, end_date, encounter_type.id, 2, 14, ward])
    @total_admissions_children_ids = @total_admissions_children.map(&:patient_id) rescue nil
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    @total_admissions_adults = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ? AND
      encounter_type =? AND DATEDIFF(NOW(), person.birthdate)/365 > 14  AND value_text =?",start_date, end_date, encounter_type.id, ward])
    @total_admissions_adults_ids = @total_admissions_adults.map(&:patient_id) rescue nil

  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    @admission_diagnoses = {}
    admission_diagnosis_enc = EncounterType.find_by_name('ADMISSION DIAGNOSIS')
    diagnosis_concept_id = Concept.find_by_name('PRIMARY DIAGNOSIS').id
    admission_diagnosis_encs = Encounter.find(:all, :joins => [:observations],\
      :conditions => ["encounter_datetime >= ? AND
    encounter_datetime <= ? AND encounter_type =? AND value_text =?", start_date, end_date, admission_diagnosis_enc.id, ward])


    admission_diagnosis_encs.each do |enc|
     observations = enc.observations.find(:all, :conditions => ["concept_id =? AND person_id IN (?)", diagnosis_concept_id, @total_admissions_ids])
       observations.each do |obs|
         if (@admission_diagnoses[obs.answer_string.squish].blank?)
          @admission_diagnoses[obs.answer_string.squish] = {}
          @admission_diagnoses[obs.answer_string.squish]["count"] = 0
          @admission_diagnoses[obs.answer_string.squish]["patient_ids"] = []
         end

         unless (@admission_diagnoses[obs.answer_string.squish].blank?)
          @admission_diagnoses[obs.answer_string.squish]["count"]+=1
          @admission_diagnoses[obs.answer_string.squish]["patient_ids"] << obs.person_id
         end
       end
    end
    @admission_diagnoses = @admission_diagnoses.sort_by{|key, value|value["count"]}.reverse
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  @discharge_diagnoses = {}
    discharge_diagnosis_enc = EncounterType.find_by_name('DISCHARGE DIAGNOSIS')
     discharge_diagnosis_encs = Encounter.find(:all, :joins => [:observations],
       :conditions => ["encounter_datetime >= ? AND
      encounter_datetime <= ? AND
      encounter_type =? AND value_text =?", start_date, end_date, discharge_diagnosis_enc.id,ward])
    discharge_diagnosis_encs.each do |enc|
     observations = enc.observations.find(:all, :conditions => ["concept_id =? AND person_id IN (?)", diagnosis_concept_id, @total_admissions_ids])
       observations.each do |obs|
         if (@discharge_diagnoses[obs.answer_string.squish].blank?)
          @discharge_diagnoses[obs.answer_string.squish] = {}
          @discharge_diagnoses[obs.answer_string.squish]["count"] = 0
          @discharge_diagnoses[obs.answer_string.squish]["patient_ids"] = []
         end

         unless (@discharge_diagnoses[obs.answer_string.squish].blank?)
          @discharge_diagnoses[obs.answer_string.squish]["count"]+=1
          @discharge_diagnoses[obs.answer_string.squish]["patient_ids"] << obs.person_id
         end
       end
    end
    @discharge_diagnoses = @discharge_diagnoses.sort_by{|key, value|value["count"]}.reverse
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    bed_size = Ward.find(:first, :conditions => ["name =? AND voided =?",ward, 0]).bed_number.to_i rescue 0
    total_discharges = Encounter.find(:all, :joins => [:observations],
      :conditions => ["encounter_datetime >= ? AND
      encounter_datetime <= ? AND
      encounter_type =? AND patient_id IN (?) AND value_text =?", start_date, end_date, discharge_diagnosis_enc.id, @total_admissions_ids, ward])

    @turn_over_rate = total_discharges.count/bed_size rescue 0
    @bed_occupacy_ratio = @total_admissions.count/bed_size rescue 0
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  @patient_states = {}
    patient_states = PatientState.find(:all, :joins => [:patient_program => [:patient => [:encounters => :observations]]],
      :conditions => ["patient_program.patient_id IN (?) AND
    start_date >= ? AND value_text =?", @total_admissions_ids, start_date.to_date, ward])
    patient_states.each do |state|
      fullname = state.program_workflow_state.concept.fullname
      next unless fullname.match(/died|Discharged|Patient transferred|Absconded/i)
      if (@patient_states[fullname].blank?)
        @patient_states[fullname] = {}
        @patient_states[fullname]["count"] = 0
        @patient_states[fullname]["patient_ids"] = []
      end

      unless (@patient_states[fullname].blank?)
        @patient_states[fullname]["count"]+=1
        @patient_states[fullname]["patient_ids"] << state.patient_program.patient_id
      end
    end
    @patient_states = @patient_states.sort_by{|key, value|value["count"]}.reverse
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
   program_id = Program.find_by_name('IPD PROGRAM').id
    admission_days = []
    total_admission_days = 0
    @total_admissions_ids.uniq.each do |patient_id|
      patient = Patient.find(patient_id)
      ipd_programs = patient.patient_programs.select{|p| p.program_id == program_id }
      ipd_programs.each do |program|
        start_date = program.date_enrolled.to_date
        if (program.closed?)
          end_date = program.date_completed.to_date
        else
          end_date = Date.today
        end
        days_in_hospital = (end_date - start_date).to_i
        admission_days << days_in_hospital.abs
      end
    end
    admission_days.each do |days|
      total_admission_days+=days
    end
    @average_length_of_stay = total_admission_days/@total_admissions_ids.count rescue 0

  render :layout => false
  end

def team_report_printable
  
    @location_name = Location.current_health_center.name rescue nil
    @logo = CoreService.get_global_property_value('logo').to_s rescue nil
    start_date = params[:start_date].to_date
    end_date = params[:end_date].to_date
    team = params[:team]
    @start_date = start_date
    @end_date = end_date
    @team = team
    #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    encounter_type = EncounterType.find_by_name("ADMIT PATIENT")

    @total_admissions = Encounter.find(:all, :joins => [:observations],:conditions => ["DATE(encounter_datetime) >= ? AND
      DATE(encounter_datetime) <= ? AND encounter_type =? AND value_text =?",\
      start_date.to_date, end_date.to_date, encounter_type.id, team])
	@total_admissions_ids = @total_admissions.map(&:patient_id)

	@total_admissions_males = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND gender =? AND value_text =?",start_date.to_date, end_date.to_date, encounter_type.id, "M", team])
   @total_admissions_males_ids = @total_admissions_males.map(&:patient_id)

   @total_admissions_females = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND gender =? AND value_text =?",start_date.to_date, end_date.to_date, encounter_type.id, "F", team])
   @total_admissions_females_ids = @total_admissions_females.map(&:patient_id)

   @total_admissions_infants = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND DATEDIFF(NOW(), person.birthdate)/365 <= 2  AND value_text =?",\
      start_date.to_date, end_date.to_date, encounter_type.id, team])
   @total_admissions_infants_ids = @total_admissions_infants.map(&:patient_id) rescue nil

  @total_admissions_children = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND DATEDIFF(NOW(), person.birthdate)/365 > ? AND
      DATEDIFF(NOW(), person.birthdate)/365 <= ? AND value_text =?",start_date.to_date, end_date.to_date, encounter_type.id, 2, 14, team])
  @total_admissions_children_ids = @total_admissions_children.map(&:patient_id) rescue nil
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  @total_admissions_adults = Encounter.find(:all, :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND
      encounter_type =? AND DATEDIFF(NOW(), person.birthdate)/365 > 14  AND value_text =?",start_date.to_date, end_date.to_date, encounter_type.id, team])
  @total_admissions_adults_ids = @total_admissions_adults.map(&:patient_id) rescue nil

  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  @admission_diagnoses = {}
    admission_diagnosis_enc = EncounterType.find_by_name('ADMISSION DIAGNOSIS')
    diagnosis_concept_id = Concept.find_by_name('PRIMARY DIAGNOSIS').id
    admission_diagnosis_encs = Encounter.find(:all, :joins => [:observations],
      :conditions => ["DATE(encounter_datetime) >= ? AND
  DATE(encounter_datetime) <= ? AND
      encounter_type =? AND value_text =?", start_date, end_date, admission_diagnosis_enc.id, team])


    admission_diagnosis_encs.each do |enc|
     observations = enc.observations.find(:all, :conditions => ["concept_id =? AND person_id IN (?)", diagnosis_concept_id, @total_admissions_ids])
       observations.each do |obs|
         if (@admission_diagnoses[obs.answer_string.squish].blank?)
          @admission_diagnoses[obs.answer_string.squish] = {}
          @admission_diagnoses[obs.answer_string.squish]["count"] = 0
          @admission_diagnoses[obs.answer_string.squish]["patient_ids"] = []
         end

         unless (@admission_diagnoses[obs.answer_string.squish].blank?)
          @admission_diagnoses[obs.answer_string.squish]["count"]+=1
          @admission_diagnoses[obs.answer_string.squish]["patient_ids"] << obs.person_id
         end
       end
    end
    @admission_diagnoses = @admission_diagnoses.sort_by{|key, value|value["count"]}.reverse
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  @discharge_diagnoses = {}
    discharge_diagnosis_enc = EncounterType.find_by_name('DISCHARGE DIAGNOSIS')
     discharge_diagnosis_encs = Encounter.find(:all, :joins => [:observations],
       :conditions => ["DATE(encounter_datetime) >= ? AND
      DATE(encounter_datetime) <= ? AND
      encounter_type =? AND value_text =?", start_date, end_date, discharge_diagnosis_enc.id, team])
    discharge_diagnosis_encs.each do |enc|
     observations = enc.observations.find(:all, :conditions => ["concept_id =? AND person_id IN (?)", diagnosis_concept_id, @total_admissions_ids])
       observations.each do |obs|
         if (@discharge_diagnoses[obs.answer_string.squish].blank?)
          @discharge_diagnoses[obs.answer_string.squish] = {}
          @discharge_diagnoses[obs.answer_string.squish]["count"] = 0
          @discharge_diagnoses[obs.answer_string.squish]["patient_ids"] = []
         end

         unless (@discharge_diagnoses[obs.answer_string.squish].blank?)
          @discharge_diagnoses[obs.answer_string.squish]["count"]+=1
          @discharge_diagnoses[obs.answer_string.squish]["patient_ids"] << obs.person_id
         end
       end
    end
    @discharge_diagnoses = @discharge_diagnoses.sort_by{|key, value|value["count"]}.reverse
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    bed_size = Ward.find(:first, :conditions => ["name =? AND voided =?",ward, 0]).bed_number.to_i rescue 0
    total_discharges = Encounter.find(:all, :conditions => ["DATE(encounter_datetime) >= ? AND
      DATE(encounter_datetime) <= ? AND
      encounter_type =? AND patient_id IN (?)", start_date, end_date, discharge_diagnosis_enc.id, @total_admissions_ids])

    @turn_over_rate = total_discharges.count/bed_size rescue 0
    @bed_occupacy_ratio = @total_admissions.count/bed_size rescue 0
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  @patient_states = {}
    patient_states = PatientState.find(:all, :joins => [:patient_program  => [:patient => [:encounters => :observations]]],\
        :conditions => ["patient_program.patient_id IN (?) AND
    start_date >= ? AND value_text =?", @total_admissions_ids, start_date, team])
    patient_states.each do |state|
      fullname = state.program_workflow_state.concept.fullname
      next unless fullname.match(/died|Discharged|Patient transferred|Absconded/i)
      if (@patient_states[fullname].blank?)
        @patient_states[fullname] = {}
        @patient_states[fullname]["count"] = 0
        @patient_states[fullname]["patient_ids"] = []
      end

      unless (@patient_states[fullname].blank?)
        @patient_states[fullname]["count"]+=1
        @patient_states[fullname]["patient_ids"] << state.patient_program.patient_id
      end
    end
    @patient_states = @patient_states.sort_by{|key, value|value["count"]}.reverse
  #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
   program_id = Program.find_by_name('IPD PROGRAM').id
    admission_days = []
    total_admission_days = 0
    @total_admissions_ids.uniq.each do |patient_id|
      patient = Patient.find(patient_id)
      ipd_programs = patient.patient_programs.select{|p| p.program_id == program_id }
      ipd_programs.each do |program|
        start_date = program.date_enrolled.to_date
        if (program.closed?)
          end_date = program.date_completed.to_date
        else
          end_date = Date.today
        end
        days_in_hospital = (end_date - start_date).to_i
        admission_days << days_in_hospital.abs
      end
    end
    admission_days.each do |days|
      total_admission_days+=days
    end
    @average_length_of_stay = total_admission_days/@total_admissions_ids.count rescue 0

  render :layout => false

end

def print_adt_generic_report
      location = request.remote_ip rescue ""
      start_date = params[:start_date]
      end_date = params[:end_date]
      current_printer = ""

      wards = CoreService.get_global_property_value("facility.ward.printers").split(",") rescue []
      wards.each{|ward|
        current_printer = ward.split(":")[1] if ward.split(":")[0].upcase == location
      } rescue []

        t1 = Thread.new{
          Kernel.system "wkhtmltopdf --margin-top 0 --margin-bottom 0 -s A4 http://" +
            request.env["HTTP_HOST"] + "\"/report/adt_generic_report_printable/" +
            "?start_date=#{start_date}&end_date=#{end_date}" + "\" /tmp/output-adt_generic_report" + ".pdf \n"
        }
        file = "/tmp/output-adt_generic_report" + ".pdf"
        t2 = Thread.new{
          sleep(3)
          print(file, current_printer)
        }
        render :text => "true" and return
end

def print_adt_report_by_ward
      location = request.remote_ip rescue ""
      start_date = params[:start_date]
      end_date = params[:end_date]
      ward_selected = params[:ward]
      current_printer = ""

      wards = CoreService.get_global_property_value("facility.ward.printers").split(",") rescue []
      wards.each{|ward|
        current_printer = ward.split(":")[1] if ward.split(":")[0].upcase == location
      } rescue []

        t1 = Thread.new{
          Kernel.system "wkhtmltopdf --margin-top 0 --margin-bottom 0 -s A4 http://" +
            request.env["HTTP_HOST"] + "\"/report/adt_report_by_ward_printable/" +
            "?start_date=#{start_date}&end_date=#{end_date}&ward=#{ward_selected}" + "\" /tmp/output-adt_report_by_ward" + ".pdf \n"
        }
        file = "/tmp/output-adt_report_by_ward" + ".pdf"
        t2 = Thread.new{
          sleep(3)
          print(file, current_printer)
        }
        render :text => "true" and return
end

def print_shift_report
      location = request.remote_ip rescue ""
      start_time = params[:start_time]
      end_time = params[:end_time]
      shift_type = params[:shift_type]
      shift_date = params[:shift_date]
      ward_selected = params[:ward]
      current_printer = ""

      wards = CoreService.get_global_property_value("facility.ward.printers").split(",") rescue []
      wards.each{|ward|
        current_printer = ward.split(":")[1] if ward.split(":")[0].upcase == location
      } rescue []

        t1 = Thread.new{
          Kernel.system "wkhtmltopdf --margin-top 0 --margin-bottom 0 -s A4 http://" +
            request.env["HTTP_HOST"] + "\"/report/shift_report_printable/" +\
            "?start_time=#{start_time}&end_time=#{end_time}&shift_type=#{shift_type}\
          &shift_date=#{shift_date}&ward=#{ward_selected}" + "\" /tmp/output-shift_report" + ".pdf \n"
        }

        file = "/tmp/output-shift_report" + ".pdf"
        t2 = Thread.new{
          sleep(3)
          print(file, current_printer)
        }
        render :text => "true" and return
end

def print_team_report
      location = request.remote_ip rescue ""
      start_date = params[:start_date]
      end_date = params[:end_date]
      team = params[:team]
      current_printer = ""
      wards = CoreService.get_global_property_value("facility.ward.printers").split(",") rescue []
      wards.each{|ward|
        current_printer = ward.split(":")[1] if ward.split(":")[0].upcase == location
      } rescue []

        t1 = Thread.new{
          Kernel.system "wkhtmltopdf --margin-top 0 --margin-bottom 0 -s A4 http://" +
            request.env["HTTP_HOST"] + "\"/report/team_report_printable/" +\
            "?start_date=#{start_date}&end_date=#{end_date}\
          &team=#{team}" + "\" /tmp/output-team_report" + ".pdf \n"
        }

        file = "/tmp/output-team_report" + ".pdf"
        t2 = Thread.new{
          sleep(3)
          print(file, current_printer)
        }
        render :text => "true" and return
end

def print(file_name, current_printer)
    sleep(3)
    if (File.exists?(file_name))
     Kernel.system "lp -o sides=two-sided-long-edge -o fitplot #{(!current_printer.blank? ? '-d ' + current_printer.to_s : "")} #{file_name}"
    else
      print(file_name)
    end
end

def daily_report
  @logo = CoreService.get_global_property_value('logo').to_s
  @current_location_name = Location.current_health_center.name
  year = params[:year]
  month = params[:month]
  ward = params[:ward]
  start_of_month_date = ('01'.to_s  + '-' + month.to_s + '-' + year.to_s).to_date
  end_of_month_date = start_of_month_date.end_of_month
  @start_date = start_of_month_date
  @end_date = end_of_month_date
  @month = month
  @year = year
  @ward = ward
  @data = {}
  available_dates = (start_of_month_date..end_of_month_date).to_a
  encounter_type = EncounterType.find_by_name("ADMIT PATIENT")
  available_dates.each do |date|
   #<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><> <><><><><><><><><><><><><><><><><><>
    @data[date] = {}
    @data[date][:admissions_by_gender] = {}
    @data[date][:admissions_by_age_groups] = {}
    @data[date][:outcomes] = {}
    @data[date][:indicators] = {}
    total_admissions = Encounter.find(:all, :joins => [:observations],
      :conditions => ["DATE(encounter_datetime) = ? AND encounter_type =? AND
      value_text =?", date, encounter_type.id, ward])
	  total_admissions_ids = total_admissions.map(&:patient_id)

	  total_admissions_males = Encounter.find(:all,
    :joins => [:observations, [:patient => :person]],
    :conditions => ["DATE(encounter_datetime) = ? AND encounter_type =? AND
    gender =? AND value_text =?",date, encounter_type.id, "M", ward])
    total_admissions_males_ids = total_admissions_males.map(&:patient_id)
    @data[date][:admissions_by_gender][:males] = total_admissions_males_ids.uniq.count

    total_admissions_females = Encounter.find(:all,
     :joins => [:observations, [:patient => :person]],
     :conditions => ["DATE(encounter_datetime) = ? AND encounter_type =? AND
     gender =? AND value_text =?",date, encounter_type.id, "F", ward])
    total_admissions_females_ids = total_admissions_females.map(&:patient_id)
    @data[date][:admissions_by_gender][:females] = total_admissions_females_ids.uniq.count

    total_admissions_infants = Encounter.find(:all,
     :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) = ? AND encounter_type =? AND
      DATEDIFF(NOW(), person.birthdate)/365 <= 2  AND value_text =?",\
      date, encounter_type.id, ward])
    total_admissions_infants_ids = total_admissions_infants.map(&:patient_id)
    @data[date][:admissions_by_age_groups][:infants] = total_admissions_infants_ids.uniq.count

    total_admissions_children = Encounter.find(:all,
      :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) = ? AND encounter_type =? AND
      DATEDIFF(NOW(), person.birthdate)/365 > ? AND DATEDIFF(NOW(), person.birthdate)/365 <= ? AND
      value_text =?",date, encounter_type.id, 2, 14, ward])
    total_admissions_children_ids = total_admissions_children.map(&:patient_id)
    @data[date][:admissions_by_age_groups][:children] = total_admissions_children_ids.uniq.count
  
    total_admissions_adults = Encounter.find(:all,
      :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) = ? AND
      encounter_type =? AND DATEDIFF(NOW(), person.birthdate)/365 > 14 AND
      value_text =?",date, encounter_type.id, ward])
    total_admissions_adults_ids = total_admissions_adults.map(&:patient_id) rescue nil
    @data[date][:admissions_by_age_groups][:adults] = total_admissions_adults_ids.uniq.count
  
 
    bed_size = Ward.find(:first, :conditions => ["name =? AND voided =?",ward, 0]).bed_number.to_i rescue 0
    bed_occupacy_ratio = total_admissions_ids.count/bed_size rescue 0
    @data[date][:indicators][:bed_occupacy_ratio] = bed_occupacy_ratio
    states = {}

    local_patient_ids = []
    total_admissions_ids.each do |patient_id|
     last_admission = Observation.find(:last, :joins=>[:encounter], :conditions => ["person_id =?
         AND encounter_type =? AND concept_id =?",patient_id,
          EncounterType.find_by_name('ADMIT PATIENT').id,
          Concept.find_by_name('ADMIT TO WARD')])
     last_admission_location = last_admission.answer_string.squish
     next unless last_admission_location == ward
     local_patient_ids << patient_id
    end

    patient_states = PatientState.find(:all, :joins => [:patient_program],
      :conditions => ["patient_id IN (?) AND
    start_date = ?", local_patient_ids, date])
    patient_states.each do |state|
      fullname = state.program_workflow_state.concept.fullname
      next unless fullname.match(/died|Discharged|Patient transferred|Absconded/i)
      if (fullname.match(/died/i))
        if (states['died'].blank?)
          states['died'] = 0
        end
        unless (states['died'].blank?)
          states['died']+=1
        end
      end

      if (fullname.match(/Discharged/i))
        if (states['Discharged'].blank?)
          states['Discharged'] = 0
        end
        unless (states['Discharged'].blank?)
          states['Discharged']+=1
        end
      end

      if (fullname.match(/Patient transferred/i))
        if (states['Patient transferred'].blank?)
          states['Patient transferred'] = 0
        end
        unless (states['Patient transferred'].blank?)
          states['Patient transferred']+=1
        end
      end

      if (fullname.match(/Absconded/i))
        if (states['Absconded'].blank?)
          states['Absconded'] = 0
        end
        unless (states['Absconded'].blank?)
          states['Absconded']+=1
        end
      end
    end
    @data[date][:outcomes][:died] = states['died'] rescue 0
    @data[date][:outcomes][:discharged] = states['Discharged'] rescue 0
    @data[date][:outcomes][:transfered] = states['Patient transferred'] rescue 0
    @data[date][:outcomes][:absconded] = states['Absconded'] rescue 0
   #<><><><><><><><><><><><><><><><><><> <><><><><><><><><><><><><><><><><><> <><><><><><><><><><><><><><><><><><> 
  end
  @data = @data.sort_by{|key, value|key}
  render :layout => "menu"
  #raise @data.to_yaml
end
def daily_report_printable
  @logo = CoreService.get_global_property_value('logo').to_s
  @current_location_name = Location.current_health_center.name
  year = params[:year]
  month = params[:month]
  ward = params[:ward]
  @ward = ward
  start_of_month_date = ('01'.to_s  + '-' + month.to_s + '-' + year.to_s).to_date
  end_of_month_date = start_of_month_date.end_of_month
  @start_date = start_of_month_date
  @end_date = end_of_month_date
  @ward = ward
  @data = {}
  available_dates = (start_of_month_date..end_of_month_date).to_a
  encounter_type = EncounterType.find_by_name("ADMIT PATIENT")
  available_dates.each do |date|
   #<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><> <><><><><><><><><><><><><><><><><><>
    @data[date] = {}
    @data[date][:admissions_by_gender] = {}
    @data[date][:admissions_by_age_groups] = {}
    @data[date][:outcomes] = {}
    @data[date][:indicators] = {}
    total_admissions = Encounter.find(:all, :joins => [:observations],
      :conditions => ["DATE(encounter_datetime) = ? AND encounter_type =? AND
      value_text =?", date, encounter_type.id, ward])
	  total_admissions_ids = total_admissions.map(&:patient_id)

	  total_admissions_males = Encounter.find(:all,
    :joins => [:observations, [:patient => :person]],
    :conditions => ["DATE(encounter_datetime) = ? AND encounter_type =? AND
    gender =? AND value_text =?",date, encounter_type.id, "M", ward])
    total_admissions_males_ids = total_admissions_males.map(&:patient_id)
    @data[date][:admissions_by_gender][:males] = total_admissions_males_ids.uniq.count

    total_admissions_females = Encounter.find(:all,
     :joins => [:observations, [:patient => :person]],
     :conditions => ["DATE(encounter_datetime) = ? AND encounter_type =? AND
     gender =? AND value_text =?",date, encounter_type.id, "F", ward])
    total_admissions_females_ids = total_admissions_females.map(&:patient_id)
    @data[date][:admissions_by_gender][:females] = total_admissions_females_ids.uniq.count

    total_admissions_infants = Encounter.find(:all,
     :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) = ? AND encounter_type =? AND
      DATEDIFF(NOW(), person.birthdate)/365 <= 2  AND value_text =?",\
      date, encounter_type.id, ward])
    total_admissions_infants_ids = total_admissions_infants.map(&:patient_id)
    @data[date][:admissions_by_age_groups][:infants] = total_admissions_infants_ids.uniq.count

    total_admissions_children = Encounter.find(:all,
      :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) = ? AND encounter_type =? AND
      DATEDIFF(NOW(), person.birthdate)/365 > ? AND DATEDIFF(NOW(), person.birthdate)/365 <= ? AND
      value_text =?",date, encounter_type.id, 2, 14, ward])
    total_admissions_children_ids = total_admissions_children.map(&:patient_id)
    @data[date][:admissions_by_age_groups][:children] = total_admissions_children_ids.uniq.count
  
    total_admissions_adults = Encounter.find(:all,
      :joins => [:observations, [:patient => :person]],
      :conditions => ["DATE(encounter_datetime) = ? AND
      encounter_type =? AND DATEDIFF(NOW(), person.birthdate)/365 > 14 AND
      value_text =?",date, encounter_type.id, ward])
    total_admissions_adults_ids = total_admissions_adults.map(&:patient_id) rescue nil
    @data[date][:admissions_by_age_groups][:adults] = total_admissions_adults_ids.uniq.count
  
 
    bed_size = Ward.find(:first, :conditions => ["name =? AND voided =?",ward, 0]).bed_number.to_i rescue 0
    bed_occupacy_ratio = total_admissions_ids.count/bed_size rescue 0
    @data[date][:indicators][:bed_occupacy_ratio] = bed_occupacy_ratio
    states = {}
    patient_states = PatientState.find(:all, :joins => [:patient_program],
      :conditions => ["patient_id IN (?) AND
    start_date = ?", total_admissions_ids, date])
    patient_states.each do |state|
      fullname = state.program_workflow_state.concept.fullname
      next unless fullname.match(/died|Discharged|Patient transferred|Absconded/i)
      if (fullname.match(/died/i))
        if (states['died'].blank?)
          states['died'] = 0
        end
        unless (states['died'].blank?)
          states['died']+=1
        end
      end

      if (fullname.match(/Discharged/i))
        if (states['Discharged'].blank?)
          states['Discharged'] = 0
        end
        unless (states['Discharged'].blank?)
          states['Discharged']+=1
        end
      end

      if (fullname.match(/Patient transferred/i))
        if (states['Patient transferred'].blank?)
          states['Patient transferred'] = 0
        end
        unless (states['Patient transferred'].blank?)
          states['Patient transferred']+=1
        end
      end

      if (fullname.match(/Absconded/i))
        if (states['Absconded'].blank?)
          states['Absconded'] = 0
        end
        unless (states['Absconded'].blank?)
          states['Absconded']+=1
        end
      end
    end
    @data[date][:outcomes][:died] = states['died'] rescue 0
    @data[date][:outcomes][:discharged] = states['Discharged'] rescue 0
    @data[date][:outcomes][:transfered] = states['Patient transferred'] rescue 0
    @data[date][:outcomes][:absconded] = states['Absconded'] rescue 0
   #<><><><><><><><><><><><><><><><><><> <><><><><><><><><><><><><><><><><><> <><><><><><><><><><><><><><><><><><> 
  end
  @data = @data.sort_by{|key, value|key}
  render :layout => false
  #raise @data.to_yaml
end
def print_daily_report
  location = request.remote_ip rescue ""
  month = params[:month]
  year = params[:year]
  selected_ward = params[:ward]
  current_printer = ""

  wards = CoreService.get_global_property_value("facility.ward.printers").split(",") rescue []
  wards.each{|ward|
    current_printer = ward.split(":")[1] if ward.split(":")[0].upcase == location
  } rescue []

    t1 = Thread.new{
      Kernel.system "wkhtmltopdf --margin-top 0 --margin-bottom 5 -s A4 http://" +
        request.env["HTTP_HOST"] + "\"/report/daily_report_printable/" +
        "?month=#{month}&year=#{year}&ward=#{selected_ward}" + "\" /tmp/output-daily_report" + ".pdf \n"
    }
    file = "/tmp/output-daily_report" + ".pdf"
    t2 = Thread.new{
      sleep(3)
      print(file, current_printer)
    }
    render :text => "true" and return
end

end

class ApplicationController < GenericApplicationController
	def next_task(patient)
		session_date = session[:datetime].to_date rescue Date.today
		task = main_next_task(Location.current_location, patient, session_date)
		begin
			return task.url if task.present? && task.url.present?
			return "/patients/show/#{patient.id}" 
		rescue
			return "/patients/show/#{patient.id}" 
		end
	end

	# Try to find the next task for the patient at the given location
	def main_next_task(location, patient, session_date = Date.today)
		task = Task.new()
=begin
    program_id = Program.find_by_name('IPD PROGRAM').id
    ipd_program = patient.patient_programs.current.local.select{|p| p.program_id == program_id }.last rescue nil
    if ipd_program.blank?
      task.encounter_type = 'ADMIT PATIENT'
			task.url = "/encounters/new/admit_patient?patient_id=#{patient.id}"
    end
=end
########################################################################################
    program_id = Program.find_by_name('IPD PROGRAM').id
    ipd_program = patient.patient_programs.local.select{|p| p.program_id == program_id }.last rescue nil
    if ipd_program.blank?
      task.encounter_type = 'ADMIT PATIENT'
			task.url = "/encounters/new/admit_patient?patient_id=#{patient.id}"
    else
      if (ipd_program.closed? && ipd_program.date_completed.to_date != session_date)
       
        task.encounter_type = 'ADMIT PATIENT'
        task.url = "/encounters/new/admit_patient?patient_id=#{patient.id}"
      end
    end
#########################################################################################
location_name = patient.encounters.find(:last, :conditions => ["encounter_type =?",
    EncounterType.find_by_name('ADMIT PATIENT').id]
      ).observations.find(:last, :conditions => ["concept_id =?",
          ConceptName.find_by_name('WORKSTATION LOCATION').concept_id]
      ).value_text rescue nil
transfer_out_encounter = patient.encounters.find(:last, :conditions => ["encounter_type =? AND
    DATE(encounter_datetime) =?",
  EncounterType.find_by_name('TRANSFER OUT').id, session_date]) rescue nil
unless transfer_out_encounter.blank?
  location_id = Location.find_by_name(location_name).id rescue nil
  current_location_id = session[:location_id]
  unless (location_id.to_i == current_location_id.to_i)
    task.encounter_type = 'ADMIT PATIENT'
    task.url = "/encounters/new/admit_patient?patient_id=#{patient.id}"
  end
end
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		if is_encounter_available(patient, 'DISCHARGE PATIENT', session_date)
			if !is_encounter_available(patient, 'DISCHARGE DIAGNOSIS', session_date)
				task.encounter_type = 'DISCHARGE DIAGNOSIS'
				task.url = "/encounters/new/discharge_diagnosis?patient_id=#{patient.id}"
			end
		end

		if is_encounter_available(patient, 'ADMIT PATIENT', session_date)
			if !is_encounter_available(patient, 'ADMISSION DIAGNOSIS', session_date)
				task.encounter_type = 'ADMISSION DIAGNOSIS'
				task.url = "/encounters/new/admission_diagnosis?patient_id=#{patient.id}"
			end
		end
=begin
    if is_encounter_available(patient, 'TRANSFER OUT', session_date)
			if !is_encounter_available(patient, 'INPATIENT DIAGNOSIS', session_date)
				task.encounter_type = 'INPATIENT DIAGNOSIS'
				task.url = "/encounters/new/inpatient_diagnosis?patient_id=#{patient.id}"
			end
		end
=end
		if task.encounter_type.nil?
			task.encounter_type = 'NONE'
			task.url = "/patients/show/#{patient.id}"
		end

		return task
	end

	def is_encounter_available(patient, encounter_type, session_date)
		is_vailable = false

		encounter_available = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
						                           patient.id,EncounterType.find_by_name(encounter_type).id, session_date],
						                           :order =>'encounter_datetime DESC',:limit => 1)
		if encounter_available.blank?
			is_available = false
		else
			is_available = true
		end

		return is_available	
	end
end

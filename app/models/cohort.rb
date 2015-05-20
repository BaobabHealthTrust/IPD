class Cohort
	
	attr :cohort
	attr_accessor :start_date, :end_date, :cohort, :patients_alive_and_on_art

	#attr_accessible :cohort

	@@first_registration_date = nil
	@@program_id = nil
  
	# Initialize class
	def initialize(start_date, end_date)
		@start_date = start_date #"#{start_date} 00:00:00"
		@end_date = "#{end_date} 23:59:59"
	
		@@first_registration_date = PatientProgram.find(
		  :first,
		  :conditions =>["program_id = ? AND voided = 0",1],
		  :order => 'date_enrolled ASC'
		).date_enrolled.to_date rescue nil

		@@program_id = Program.find_by_name('HIV PROGRAM').program_id
	end

	def report(logger)
		return {} if @@first_registration_date.blank?
		cohort_report = {}
	

				cohort_report['Total Presumed severe HIV disease in infants'] = 0
				cohort_report['Total Confirmed HIV infection in infants (PCR)'] = 0
				cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] = 0
				cohort_report['Total WHO stage 2, total lymphocytes'] = 0
				cohort_report['Total Unknown reason'] = 0
				cohort_report['Total WHO stage 3'] = 0
				cohort_report['Total WHO stage 4'] = 0
				cohort_report['Total Patient pregnant'] = 0
				cohort_report['Total Patient breastfeeding'] = 0
				cohort_report['Total HIV infected'] = 0
  
				( self.start_reason(@@first_registration_date, @end_date) || [] ).each do | collection_reason |

#          total_for_start_reason_cumulative += 1
					reason = ''
					if !collection_reason.name.blank?
						reason = collection_reason.name
					end

				  if reason.match(/Presumed/i)
				    cohort_report['Total Presumed severe HIV disease in infants'] += 1
				  elsif reason.match(/Confirmed/i)
				    cohort_report['Total Confirmed HIV infection in infants (PCR)'] += 1
				  elsif reason[0..11].strip.upcase == 'WHO STAGE I' or reason.match(/CD/i)
				    cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] += 1
				  elsif reason[0..12].strip.upcase == 'WHO STAGE II' or reason.match(/lymphocytes/i) or reason.match(/LYMPHOCYTE/i)
				    cohort_report['Total WHO stage 2, total lymphocytes'] += 1
				  elsif reason[0..13].strip.upcase == 'WHO STAGE III'
				    cohort_report['Total WHO stage 3'] += 1
				  elsif reason[0..11].strip.upcase == 'WHO STAGE IV'
				    cohort_report['Total WHO stage 4'] += 1
				  elsif reason.strip.humanize == 'Patient pregnant'
				    cohort_report['Total Patient pregnant'] += 1
				  elsif reason.match(/Breastfeeding/i)
				    cohort_report['Total Patient breastfeeding'] += 1
				  elsif reason.strip.upcase == 'HIV INFECTED'
				    cohort_report['Total HIV infected'] += 1
				  else 
				    cohort_report['Total Unknown reason'] += 1
				  end
				end


		#raise self.art_defaulted_patients.length.to_s

	#	raise self.patients_with_start_cause(@start_date, @end_date, tb_concept_id = ConceptName.find_by_name("PULMONARY TUBERCULOSIS WITHIN THE LAST 2 YEARS").concept_id).to_yaml
=begin
					cohort_report['Total registered'] = self.total_registered(@@first_registration_date).length
					cohort_report['Newly total registered'] = self.total_registered.length

					logger.info("initiated_on_art " + Time.now.to_s)  
					cohort_report['Patients initiated on ART'] = self.patients_initiated_on_art_first_time.length
					cohort_report['Total Patients initiated on ART'] = self.patients_initiated_on_art_first_time(@@first_registration_date).length

					cohort_report['Total transferred in patients'] = self.transferred_in_patients(@@first_registration_date).length
					cohort_report['Newly transferred in patients'] = self.transferred_in_patients.length
					logger.info("transfered_in " + Time.now.to_s)
				
					logger.info("male " + Time.now.to_s)
					cohort_report['Newly registered male'] = self.total_registered_by_gender_age(@start_date, @end_date,'M').length
					cohort_report['Total registered male'] = self.total_registered_by_gender_age(@@first_registration_date, @end_date,'M').length

					logger.info("non-pregnant " + Time.now.to_s)
					cohort_report['Newly registered women (non-pregnant)'] = self.non_pregnant_women(@start_date, @end_date).length
					cohort_report['Total registered women (non-pregnant)'] = self.non_pregnant_women(@@first_registration_date, @end_date).length
				
					logger.info("pregnant " + Time.now.to_s)
					cohort_report['Newly registered women (pregnant)'] = self.pregnant_women(@start_date, @end_date).length
					cohort_report['Total registered women (pregnant)'] = self.pregnant_women(@@first_registration_date, @end_date).length

					logger.info("infants " + Time.now.to_s)
					cohort_report['Newly registered infants'] = self.total_registered_by_gender_age(@start_date, @end_date, nil, 0, 730).length
					cohort_report['Total registered infants'] = self.total_registered_by_gender_age(@@first_registration_date, @start_date, nil, 0, 730).length

					logger.info("children " + Time.now.to_s)
					cohort_report['Newly registered children'] = self.total_registered_by_gender_age(@start_date,@end_date,nil,1.5,14).length
					cohort_report['Total registered children'] = self.total_registered_by_gender_age(@@first_registration_date,@start_date, nil, 730, 5110).length

					logger.info("adults " + Time.now.to_s)
					cohort_report['Newly registered adults'] = self.total_registered_by_gender_age(@start_date, @end_date, nil, 5110, 109500).length
					cohort_report['Total registered adults'] = self.total_registered_by_gender_age(@@first_registration_date, @start_date, nil, 5110, 109500).length

		raise cohort_report.to_yaml
=end				
		threads = []



		threads << Thread.new do
				begin
					cohort_report['Total registered'] = self.total_registered(@@first_registration_date).length
					cohort_report['Newly total registered'] = self.total_registered.length

					logger.info("initiated_on_art " + Time.now.to_s)  
					cohort_report['Patients initiated on ART'] = self.patients_initiated_on_art_first_time.length
					cohort_report['Total Patients initiated on ART'] = self.patients_initiated_on_art_first_time(@@first_registration_date).length
				rescue Exception => e
						Thread.current[:exception] = e
				end
		end
		threads << Thread.new do
				begin
					cohort_report['Total transferred in patients'] = self.transferred_in_patients(@@first_registration_date).length
					cohort_report['Newly transferred in patients'] = self.transferred_in_patients.length
					logger.info("transfered_in " + Time.now.to_s)
				
					logger.info("male " + Time.now.to_s)
					cohort_report['Newly registered male'] = self.total_registered_by_gender_age(@start_date, @end_date,'M').length
					cohort_report['Total registered male'] = self.total_registered_by_gender_age(@@first_registration_date, @end_date,'M').length

					logger.info("non-pregnant " + Time.now.to_s)
					cohort_report['Newly registered women (non-pregnant)'] = self.non_pregnant_women(@start_date, @end_date).length
					cohort_report['Total registered women (non-pregnant)'] = self.non_pregnant_women(@@first_registration_date, @end_date).length
				rescue Exception => e
						Thread.current[:exception] = e
				end
		end
		threads << Thread.new do
				begin
					logger.info("pregnant " + Time.now.to_s)
					cohort_report['Newly registered women (pregnant)'] = self.pregnant_women(@start_date, @end_date).length
					cohort_report['Total registered women (pregnant)'] = self.pregnant_women(@@first_registration_date, @end_date).length

				rescue Exception => e
						Thread.current[:exception] = e
				end
		end
		threads << Thread.new do
				begin
					logger.info("adults " + Time.now.to_s)
					cohort_report['Newly registered adults'] = self.total_registered_by_gender_age(@start_date, @end_date, nil, 5110, 109500).length
					cohort_report['Total registered adults'] = self.total_registered_by_gender_age(@@first_registration_date, @start_date, nil, 5110, 109500).length
				rescue Exception => e
						Thread.current[:exception] = e
				end
		end
		threads << Thread.new do
				begin
					logger.info("children " + Time.now.to_s)
					cohort_report['Newly registered children'] = self.total_registered_by_gender_age(@start_date, @end_date, nil, 730, 5110).length
					cohort_report['Total registered children'] = self.total_registered_by_gender_age(@@first_registration_date, @start_date, nil, 730, 5110).length
				rescue Exception => e
						Thread.current[:exception] = e
				end
		end
		threads << Thread.new do
				begin
					logger.info("infants " + Time.now.to_s)
					cohort_report['Newly registered infants'] = self.total_registered_by_gender_age(@start_date, @end_date, nil, 0, 730).length
					cohort_report['Total registered infants'] = self.total_registered_by_gender_age(@@first_registration_date, @start_date, nil, 0, 730).length

				rescue Exception => e
						Thread.current[:exception] = e
				end
		end
=begin
		threads.each do |thread|
			thread.join
			if thread[:exception]
				 # log it somehow, or even re-raise it if you
				 # really want, it's got it's original backtrace.
				 raise thread[:exception].backtrace.to_yaml
			end
		end
		
		raise cohort_report.to_yaml
=begin
		threads = []
		threads << Thread.new do
				begin
					cohort_report['Total registered'] = self.total_registered(@@first_registration_date).length
					cohort_report['Newly total registered'] = self.total_registered.length

					logger.info("initiated_on_art " + Time.now.to_s)  
					cohort_report['Patients initiated on ART'] = self.patients_initiated_on_art_first_time.length
					cohort_report['Total Patients initiated on ART'] = self.patients_initiated_on_art_first_time(@@first_registration_date).length

					cohort_report['Total transferred in patients'] = self.transferred_in_patients(@@first_registration_date).length
					cohort_report['Newly transferred in patients'] = self.transferred_in_patients.length
					logger.info("transfered_in " + Time.now.to_s)
				
					logger.info("male " + Time.now.to_s)
					cohort_report['Newly registered male'] = self.total_registered_by_gender_age(@start_date, @end_date,'M').length
					cohort_report['Total registered male'] = self.total_registered_by_gender_age(@@first_registration_date, @end_date,'M').length

					logger.info("non-pregnant " + Time.now.to_s)
					cohort_report['Newly registered women (non-pregnant)'] = self.non_pregnant_women(@start_date, @end_date).length
					cohort_report['Total registered women (non-pregnant)'] = self.non_pregnant_women(@@first_registration_date, @end_date).length
				
					logger.info("pregnant " + Time.now.to_s)
					cohort_report['Newly registered women (pregnant)'] = self.pregnant_women(@start_date, @end_date).length
					cohort_report['Total registered women (pregnant)'] = self.pregnant_women(@@first_registration_date, @end_date).length

					logger.info("infants " + Time.now.to_s)
					cohort_report['Newly registered infants'] = self.total_registered_by_gender_age(@start_date, @end_date, nil, 0, 730).length
					cohort_report['Total registered infants'] = self.total_registered_by_gender_age(@@first_registration_date, @start_date, nil, 0, 730).length

					logger.info("children " + Time.now.to_s)
					cohort_report['Newly registered children'] = self.total_registered_by_gender_age(@start_date,@end_date,nil,1.5,14).length
					cohort_report['Total registered children'] = self.total_registered_by_gender_age(@@first_registration_date,@start_date, nil, 730, 5110).length

					logger.info("adults " + Time.now.to_s)
					cohort_report['Newly registered adults'] = self.total_registered_by_gender_age(@start_date, @end_date, nil, 5110, 109500).length
					cohort_report['Total registered adults'] = self.total_registered_by_gender_age(@@first_registration_date, @start_date, nil, 5110, 109500).length

				rescue Exception => e
						Thread.current[:exception] = e
				end
		end
=end
		
		threads << Thread.new do
			begin
				logger.info("reinitiated_on_art " + Time.now.to_s)    
				cohort_report['Patients reinitiated on ART'] = self.patients_reinitiated_on_art.length
				cohort_report['Total Patients reinitiated on ART'] = self.patients_reinitiated_on_art(@@first_registration_date).length

			rescue Exception => e
				Thread.current[:exception] = e
			end
		end    

=begin   
		threads << Thread.new do
			begin

				cohort_report['Total Presumed severe HIV disease in infants'] = 0
				cohort_report['Total Confirmed HIV infection in infants (PCR)'] = 0
				cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] = 0
				cohort_report['Total WHO stage 2, total lymphocytes'] = 0
				cohort_report['Total Unknown reason'] = 0
				cohort_report['Total WHO stage 3'] = 0
				cohort_report['Total WHO stage 4'] = 0
				cohort_report['Total Patient pregnant'] = 0
				cohort_report['Total Patient breastfeeding'] = 0
				cohort_report['Total HIV infected'] = 0
  
				( self.start_reason(@@first_registration_date, @end_date) || [] ).each do | collection_reason |

#          total_for_start_reason_cumulative += 1
					reason = ''
					if !collection_reason.name.blank?
						reason = collection_reason.name
					end

				  if reason.match(/Presumed/i)
				    cohort_report['Total Presumed severe HIV disease in infants'] += 1
				  elsif reason.match(/Confirmed/i)
				    cohort_report['Total Confirmed HIV infection in infants (PCR)'] += 1
				  elsif reason[0..11].strip.upcase == 'WHO STAGE I' or reason.match(/CD/i)
				    cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] += 1
				  elsif reason[0..12].strip.upcase == 'WHO STAGE II' or reason.match(/lymphocytes/i) or reason.match(/LYMPHOCYTE/i)
				    cohort_report['Total WHO stage 2, total lymphocytes'] += 1
				  elsif reason[0..13].strip.upcase == 'WHO STAGE III'
				    cohort_report['Total WHO stage 3'] += 1
				  elsif reason[0..11].strip.upcase == 'WHO STAGE IV'
				    cohort_report['Total WHO stage 4'] += 1
				  elsif reason.strip.humanize == 'Patient pregnant'
				    cohort_report['Total Patient pregnant'] += 1
				  elsif reason.match(/Breastfeeding/i)
				    cohort_report['Total Patient breastfeeding'] += 1
				  elsif reason.strip.upcase == 'HIV INFECTED'
				    cohort_report['Total HIV infected'] += 1
				  else 
				    cohort_report['Total Unknown reason'] += 1
				  end
				end

		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end
=end
		threads << Thread.new do
			begin
				logger.info("start_reason " + Time.now.to_s)
				cohort_report['Presumed severe HIV disease in infants'] = 0
				cohort_report['Confirmed HIV infection in infants (PCR)'] = 0
				cohort_report['WHO stage 1 or 2, CD4 below threshold'] = 0
				cohort_report['WHO stage 2, total lymphocytes'] = 0
				cohort_report['Unknown reason'] = 0
				cohort_report['WHO stage 3'] = 0
				cohort_report['WHO stage 4'] = 0
				cohort_report['Patient pregnant'] = 0
				cohort_report['Patient breastfeeding'] = 0
				cohort_report['HIV infected'] = 0

 				( self.start_reason || [] ).each do | collection_reason |

#					total_for_start_reason_quarterly += 1
					reason = ''
					if !collection_reason.name.blank?
						reason = collection_reason.name
					end

				  if reason.match(/Presumed/i)
				    cohort_report['Presumed severe HIV disease in infants'] += 1
				  elsif reason.match(/Confirmed/i)
				    cohort_report['Confirmed HIV infection in infants (PCR)'] += 1
				  elsif reason[0..11].strip.upcase == 'WHO STAGE I' or reason.match(/CD/i)
				    cohort_report['WHO stage 1 or 2, CD4 below threshold'] += 1
				  elsif reason[0..12].strip.upcase == 'WHO STAGE II' or reason.match(/lymphocytes/i) or reason.match(/LYMPHOCYTE/i)
				    cohort_report['WHO stage 2, total lymphocytes'] += 1
				  elsif reason[0..13].strip.upcase == 'WHO STAGE III'
				    cohort_report['WHO stage 3'] += 1
				  elsif reason[0..11].strip.upcase == 'WHO STAGE IV'
				    cohort_report['WHO stage 4'] += 1
				  elsif reason.strip.humanize == 'Patient pregnant'
				    cohort_report['Patient pregnant'] += 1
				  elsif reason.match(/Breastfeeding/i)
				    cohort_report['Patient breastfeeding'] += 1
				  elsif reason.strip.upcase == 'HIV INFECTED'
				    cohort_report['HIV infected'] += 1
				  else 
				    cohort_report['Unknown reason'] += 1
				  end
				end
	

		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads << Thread.new do
			begin
				logger.info("alive_on_art " + Time.now.to_s)
        @patients_alive_and_on_art = self.total_alive_and_on_art
				cohort_report['Total alive and on ART'] = @patients_alive_and_on_art.length
				cohort_report['Died total'] = self.total_number_of_dead_patients.length

				logger.info("death_dates " + Time.now.to_s)
				# death_dates_array = self.death_dates
				cohort_report['Died within the 1st month after ART initiation'] = self.total_number_of_died_within_range(0, 29).length
				cohort_report['Died within the 2nd month after ART initiation'] = self.total_number_of_died_within_range(29, 57).length
				cohort_report['Died within the 3rd month after ART initiation'] = self.total_number_of_died_within_range(57, 85).length
				cohort_report['Died after the end of the 3rd month after ART initiation'] = self.total_number_of_died_within_range(85, 1000000).length
=begin			
				death_dates_array = self.death_dates(@@first_registration_date,@end_date)
				cohort_report['Total Died within the 1st month after ART initiation'] = death_dates_array[0].length
				cohort_report['Total Died within the 2nd month after ART initiation'] = death_dates_array[1].length
				cohort_report['Total Died within the 3rd month after ART initiation'] = death_dates_array[2].length
				cohort_report['Total Died after the end of the 3rd month after ART initiation'] = death_dates_array[3].length
=end
				logger.info("txfrd_out " + Time.now.to_s)
				cohort_report['Transferred out'] = self.transferred_out_patients.length
				
				logger.info("stopped_arvs " + Time.now.to_s)
				cohort_report['Stopped taking ARVs'] = self.art_stopped_patients.length
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end
=begin
		threads.each do |thread|
			thread.join
			if thread[:exception]
				 # log it somehow, or even re-raise it if you
				 # really want, it's got it's original backtrace.
				 raise thread[:exception].backtrace.to_yaml
			end
		end
		
		raise cohort_report.to_yaml		  
=end	  



		threads << Thread.new do
			begin
				logger.info("defaulted " + Time.now.to_s)    
				cohort_report['Defaulted'] = self.art_defaulted_patients.length

				logger.info("tb_status " + Time.now.to_s)
				tb_status_outcomes = self.tb_status
				cohort_report['TB suspected'] = tb_status_outcomes['TB STATUS']['Suspected'].length
				cohort_report['TB not suspected'] = tb_status_outcomes['TB STATUS']['Not Suspected'].length
				cohort_report['TB confirmed not treatment'] = tb_status_outcomes['TB STATUS']['Not on treatment'].length
				cohort_report['TB confirmed on treatment'] = tb_status_outcomes['TB STATUS']['On Treatment'].length
				cohort_report['TB Unknown'] = tb_status_outcomes['TB STATUS']['Unknown'].length
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads << Thread.new do
			begin
				logger.info("regimens " + Time.now.to_s)
				cohort_report['Regimens'] = self.regimens(@@first_registration_date)
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end


		threads.each do |thread|				
			thread.join
			if thread[:exception]
				 # log it somehow, or even re-raise it if you
				 # really want, it's got it's original backtrace.
				 raise thread[:exception].message + ' ' + thread[:exception].backtrace.to_s
			end
		end
		
		threads = []
		threads << Thread.new do
			begin
		    	cohort_report['Total patients with side effects'] = self.patients_with_side_effects.length

				logger.info("current_episode_of_tb " + Time.now.to_s)
				cohort_report['Current episode of TB'] = self.current_episode_of_tb.length
				cohort_report['Total Current episode of TB'] = self.current_episode_of_tb(@@first_registration_date, @end_date).length
			rescue Exception => e
				Thread.current[:exception] = e
			end
		end

		threads << Thread.new do
			begin
				logger.info("tb_within_last_year " + Time.now.to_s)
				cohort_report['TB within the last 2 years'] = self.tb_within_the_last_2_yrs.length
				cohort_report['Total TB within the last 2 years'] = self.tb_within_the_last_2_yrs(@@first_registration_date, @end_date).length

				logger.info("ks " + Time.now.to_s)
				cohort_report['Kaposis Sarcoma'] = self.kaposis_sarcoma.length
				cohort_report['Total Kaposis Sarcoma'] = self.kaposis_sarcoma(@@first_registration_date,@end_date).length
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads.each do |thread|				
			thread.join
			if thread[:exception]
				 # log it somehow, or even re-raise it if you
				 # really want, it's got it's original backtrace.
				 raise thread[:exception].message + ' ' + thread[:exception].backtrace.to_s
			end
		end

		cohort_report['No TB'] = (cohort_report['Newly total registered'] - (cohort_report['Current episode of TB'] + cohort_report['TB within the last 2 years']))
		cohort_report['Total No TB'] = (cohort_report['Total registered'] - (cohort_report['Total Current episode of TB'] + cohort_report['Total TB within the last 2 years']))

#cohort_report['Unknown reason'] += (cohort_report['Newly total registered'] - total_for_start_reason_quarterly)
#cohort_report['Total Unknown reason'] += (cohort_report['Newly total registered'] - total_for_start_reason_cumulative)
    cohort_report['Unknown outcomes'] = cohort_report['Total registered'] -
                                        (cohort_report['Total alive and on ART'] +
                                          cohort_report['Defaulted'] +
                                          cohort_report['Died total'] +
                                          cohort_report['Stopped taking ARVs'] +
                                          cohort_report['Transferred out'])
    
    cohort_report['Regimens']['UNKNOWN ANTIRETROVIRAL DRUG'] += (cohort_report['Total alive and on ART'] -
                                                                 cohort_report['Regimens'].values.sum)

		self.cohort = cohort_report
		self.cohort
	end

	def total_registered(start_date = @start_date, end_date = @end_date)
		#start_date = @start_date
		#end_date = @end_date
		on_art_concept_name = ConceptName.find_all_by_name('On antiretrovirals')
		state = ProgramWorkflowState.find(
			:first,
			:conditions => ["concept_id IN (?)",
				on_art_concept_name.map{|c|c.concept_id}]
			).program_workflow_state_id
	
		PatientProgram.find_by_sql("SELECT p.patient_id, MIN(s.start_date) AS earliest_start_date
			FROM patient_program p
				LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
			WHERE p.voided = 0
				AND s.voided = 0
				AND program_id = #{@@program_id}
				AND s.state = #{state}
			GROUP BY p.patient_id
			HAVING 
				earliest_start_date >= '#{start_date}'
				AND earliest_start_date <= '#{end_date}'")
=begin    
PatientProgram.find_by_sql("SELECT patient_id FROM patient_program p
	                        INNER JOIN patient_state s USING (patient_program_id)
	                        WHERE p.voided = 0
	                        AND s.voided = 0
	                        AND program_id = #{@@program_id}
	                        AND s.state = #{state}
	                        AND patient_start_date(patient_id) >= '#{start_date}'
	                        AND patient_start_date(patient_id) <= '#{end_date}'
	                        GROUP BY patient_id ORDER BY date_enrolled")#.length rescue 0
=end  
	end

	def patients_initiated_on_art_first_time(start_date = @start_date, end_date = @end_date)
		on_art_concept_name = ConceptName.find_all_by_name('On antiretrovirals')
		state = ProgramWorkflowState.find(
			:first,
			:conditions => ["concept_id IN (?)",
				on_art_concept_name.map{|c|c.concept_id}]
			).program_workflow_state_id
	
		PatientProgram.find_by_sql("SELECT p.patient_id, MIN(s.start_date) AS earliest_start_date, MIN(o.value_datetime) AS original_start_date
			FROM patient_program p
				LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
				LEFT JOIN clinic_registration_encounter e ON p.patient_id = e.patient_id
				LEFT JOIN start_date_observation o ON o.encounter_id = e.encounter_id
			WHERE p.voided = 0
				AND s.voided = 0
				AND program_id = #{@@program_id}
				AND s.state = #{state}
			GROUP BY p.patient_id
			HAVING 
				earliest_start_date >= '#{start_date}'
				AND earliest_start_date <= '#{end_date}'
				AND	original_start_date IS NULL")

=begin    
PatientProgram.find_by_sql("SELECT 
		                patient_id ,obs_datetime visit_date,value_coded,obs.concept_id concept_id  
		                FROM obs 
		                INNER JOIN patient_program p ON p.patient_id = obs.person_id
		                INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id
		                WHERE p.program_id = #{@@program_id}
		                AND obs.value_coded = #{no_concept.concept_id}
		                AND obs.concept_id = #{ever_received_concept_id}
		                AND patient_start_date(patient_id) >= '#{start_date}'
		                AND patient_start_date(patient_id) <= '#{end_date}' 
		                GROUP BY patient_id 
		                ORDER BY obs.obs_datetime DESC") rescue 0
=end  
	end

	def transferred_in_patients(start_date = @start_date, end_date = @end_date)
		on_art_concept_name = ConceptName.find_all_by_name('On antiretrovirals')
		state = ProgramWorkflowState.find(
			:first,
			:conditions => ["concept_id IN (?)",
				on_art_concept_name.map{|c|c.concept_id}]
			).program_workflow_state_id
	
		PatientProgram.find_by_sql("SELECT p.patient_id, MIN(s.start_date) AS earliest_start_date, MIN(o.value_datetime) AS original_start_date
			FROM patient_program p
				LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
				LEFT JOIN clinic_registration_encounter e ON p.patient_id = e.patient_id
				LEFT JOIN start_date_observation o ON o.encounter_id = e.encounter_id
			WHERE p.voided = 0
				AND s.voided = 0
				AND program_id = #{@@program_id}
				AND s.state = #{state}
			GROUP BY p.patient_id
			HAVING 
				earliest_start_date >= '#{start_date}'
				AND earliest_start_date <= '#{end_date}'
				AND	original_start_date IS NOT NULL")
=begin
PatientProgram.find_by_sql("SELECT p.patient_id, IFNULL(MIN(o.value_datetime), MIN(s.start_date)), MIN(o.value_datetime) AS original_start_date FROM patient_program p
										LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
        LEFT JOIN obs ON obs.person_id = p.patient_id 
        LEFT JOIN clinic_registration_encounter e ON p.patient_id = e.patient_id
										LEFT JOIN start_date_observation o ON o.encounter_id = e.encounter_id
        WHERE p.voided = 0
        AND s.voided = 0
        AND program_id = #{@@program_id}
        AND obs.voided = 0
        AND s.start_date >= '#{start_date}'
									AND s.start_date <= '#{end_date}'
        AND obs.concept_id = #{ever_received_concept_id}
        AND obs.value_coded = #{yes_concept_id}
        GROUP BY patient_id
        HAVING original_start_date IS NOT NULL") #rescue 0
=end
	end

	def total_registered_by_gender_age(start_date = @start_date, end_date = @end_date, sex = nil, min_age = nil, max_age = nil)

		on_art_concept_name = ConceptName.find_all_by_name('On antiretrovirals')
		state = ProgramWorkflowState.find(
			:first,
			:conditions => ["concept_id IN (?)",
				on_art_concept_name.map{|c|c.concept_id}]
			).program_workflow_state_id
		conditions = ''

=begin

			yes_concept_id = ConceptName.find_by_name("YES").concept_id
		if min_age and max_age
		  conditions = "AND TRUNCATE(DATEDIFF(date_enrolled, person.birthdate)/365, 0) >= #{min_age}
				        AND TRUNCATE(DATEDIFF(date_enrolled, person.birthdate)/365, 0) <= #{max_age}"
		end
=end
		if min_age and max_age
		  conditions = "AND DATEDIFF(date_enrolled, person.birthdate) >= #{min_age}
				        AND DATEDIFF(date_enrolled, person.birthdate) < #{max_age}"
		end

		if sex
		  conditions += " AND person.gender = '#{sex}'"
		end
=begin
PatientProgram.find_by_sql("SELECT patient_id,program_id,count(*) FROM patient_program p
		                    INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id
		                    INNER JOIN obs ON obs.person_id = p.patient_id 
		                    INNER JOIN person ON person.person_id = p.patient_id 
		                    WHERE p.voided = 0
		                    AND s.voided = 0
		                    AND program_id = 1
		                    AND obs.voided = 0
		                    AND patient_start_date(p.patient_id) >= '#{start_date}'
		                    AND patient_start_date(p.patient_id) <= '#{end_date}'
		                    #{conditions} GROUP BY patient_id")
=end

		PatientProgram.find_by_sql("SELECT p.patient_id, MIN(s.start_date) AS earliest_start_date
			FROM patient_program p
				LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
				LEFT JOIN person ON person.person_id = p.patient_id
			WHERE p.voided = 0
				AND person.voided = 0
				AND s.voided = 0
				AND program_id = #{@@program_id}
				AND s.state = #{state}
				#{conditions} 
			GROUP BY p.patient_id
			HAVING 
				earliest_start_date >= '#{start_date}'
				AND earliest_start_date <= '#{end_date}'")

=begin
					PatientProgram.find_by_sql("SELECT p.patient_id, person.gender, program_id, IFNULL(MIN(o.value_datetime), MIN(s.start_date)), MIN(o.value_datetime) AS original_start_date, count(*) FROM patient_program p
				 	LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
					LEFT JOIN clinic_registration_encounter e ON p.patient_id = e.patient_id
					LEFT JOIN start_date_observation o ON o.encounter_id = e.encounter_id
				 	LEFT JOIN person ON person.person_id = p.patient_id 
				 	WHERE p.voided = 0
				 	AND s.voided = 0
				 	AND program_id = #{@@program_id}
				 	AND s.start_date >= '#{start_date}'
				 	AND s.start_date <= '#{end_date}'
				 	#{conditions} GROUP BY patient_id HAVING original_start_date IS NULL ")
=end	 
	end

	def non_pregnant_women(start_date = @start_date, end_date = @end_date)
		all_women =  self.total_registered_by_gender_age(start_date, end_date, 'F').map{|patient| patient.patient_id}
		non_pregnant_women = (all_women - self.pregnant_women(start_date, end_date).map{|patient| patient.patient_id})
	end

	def pregnant_women(start_date = @start_date, end_date = @end_date)

		PatientProgram.find_by_sql("SELECT patient_id, earliest_start_date, o.obs_datetime 
				FROM earliest_start_date p
					INNER JOIN patient_pregnant_obs o ON p.patient_id = o.person_id
				WHERE earliest_start_date >= '#{start_date}'
					AND earliest_start_date <= '#{end_date}'
					AND DATEDIFF(o.obs_datetime, earliest_start_date) <= 30
					AND DATEDIFF(o.obs_datetime, earliest_start_date) > -1
        GROUP BY patient_id")


=begin
		pregnant_concept_id = ConceptName.find_by_name("IS PATIENT PREGNANT?").concept_id
		pmtct_concept_id = ConceptName.find_by_name("REFERRED BY PMTCT").concept_id
		yes_concept_id = ConceptName.find_by_name("YES").concept_id

		PatientProgram.find_by_sql("SELECT patient_id, date_enrolled, obs.concept_id FROM obs 
						                LEFT JOIN patient_program p ON p.patient_id = obs.person_id
						                LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
						                LEFT JOIN person ON person.person_id = p.patient_id
				                    WHERE p.program_id = 1
						                AND gender ='F' 
						                AND s.start_date >= '#{start_date}'
						                AND s.start_date <= '#{end_date}' 
						                AND ((obs.concept_id = #{pregnant_concept_id}
						                AND obs.value_coded = #{yes_concept_id} )) 
						                AND (DATEDIFF(DATE(obs.obs_datetime), date_enrolled) >= 0) 
						                AND DATEDIFF(DATE(obs.obs_datetime),date_enrolled) <= 30
				                    GROUP BY patient_id")
=end
	
	end

	def start_reason(start_date = @start_date, end_date = @end_date)
		#start_reason_hash = Hash.new(0)
	    reason_concept_id = ConceptName.find_by_name("REASON FOR ART ELIGIBILITY").concept_id

=begin
		PatientProgram.find_by_sql("SELECT p.patient_id, name, date_enrolled, IFNULL(MIN(o.value_datetime), MIN(s.start_date)), MIN(o.value_datetime) AS original_start_date FROM obs
																 LEFT JOIN patient_program p ON p.patient_id = obs.person_id
																 LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
																 LEFT JOIN clinic_registration_encounter e ON p.patient_id = e.patient_id
																 LEFT JOIN start_date_observation o ON o.encounter_id = e.encounter_id
																 LEFT JOIN concept_name n ON n.concept_id = obs.value_coded
																 WHERE s.start_date >= '#{start_date}'
																 AND s.start_date <= '#{end_date}'
																 AND obs.concept_id = #{reason_concept_id}
																 AND p.program_id = #{@@program_id}
																 AND n.name != ''
																 GROUP BY patient_id")
=end

		PatientProgram.find_by_sql("SELECT e.patient_id, name FROM earliest_start_date e
											LEFT JOIN obs o ON e.patient_id = o.person_id AND o.concept_id = #{reason_concept_id} AND o.voided = 0
											LEFT JOIN concept_name n ON n.concept_id = o.value_coded AND n.concept_name_type = 'FULLY_SPECIFIED' AND n.voided = 0
										WHERE earliest_start_date >= '#{start_date}'
											AND earliest_start_date <= '#{end_date}'
										GROUP BY e.patient_id")


=begin
    PatientProgram.find_by_sql("SELECT patient_id,name,date_enrolled FROM obs
                                INNER JOIN patient_program p ON p.patient_id = obs.person_id
                                INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                                INNER JOIN concept_name n ON n.concept_id = obs.value_coded
                                WHERE patient_start_date(patient_id) >='#{start_date}'
                                AND patient_start_date(patient_id) <= '#{end_date}' 
                                AND obs.concept_id = #{reason_concept_id}
                                AND p.program_id = #{@@program_id}
                                AND n.name != ''
                                GROUP BY patient_id")
=end
	end

	def tb_within_the_last_2_yrs(start_date = @start_date, end_date = @end_date)
		tb_concept_id = ConceptName.find_by_name("PULMONARY TUBERCULOSIS WITHIN THE LAST 2 YEARS").concept_id
		self.patients_with_start_cause(start_date, end_date, tb_concept_id)
	end

	def patients_with_start_cause(start_date = @start_date, end_date = @end_date, tb_concept_id = nil)
		return if tb_concept_id.blank?
		cause_concept_id = ConceptName.find_by_name("WHO STG CRIT").concept_id
=begin
PatientProgram.find_by_sql("SELECT patient_id,name,date_enrolled FROM obs
	                        INNER JOIN patient_program p ON p.patient_id = obs.person_id
	                        INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id
	                        INNER JOIN concept_name n ON n.concept_id = obs.value_coded
	                        WHERE patient_start_date(patient_id) >='#{start_date}' AND patient_start_date(patient_id) <= '#{end_date}' 
	                        AND obs.concept_id = #{cause_concept_id} AND p.program_id = #{@@program_id}
	                        AND obs.value_coded = #{tb_concept_id} GROUP BY patient_id")#.length
=end
			Observation.find_by_sql("SELECT DISTINCT person_id AS patient_id, earliest_start_date FROM obs INNER JOIN earliest_start_date e ON obs.person_id = e.patient_id
				WHERE encounter_id IN (SELECT encounter_id FROM obs 
						WHERE concept_id = 7563 AND value_coded != 1107	AND voided = 0) 
					AND concept_id = #{tb_concept_id} 
					AND voided = 0
					AND earliest_start_date >= '#{start_date}'
					AND earliest_start_date <= '#{end_date}'")

=begin
			PatientProgram.find_by_sql("SELECT p.patient_id,name,date_enrolled, IFNULL(MIN(o.value_datetime), MIN(s.start_date)), MIN(o.value_datetime) AS original_start_date FROM obs
																 LEFT JOIN patient_program p ON p.patient_id = obs.person_id
																 LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
																 LEFT JOIN concept_name n ON n.concept_id = obs.value_coded
																 LEFT JOIN clinic_registration_encounter e ON p.patient_id = e.patient_id
																 LEFT JOIN start_date_observation o ON o.encounter_id = e.encounter_id
																 WHERE s.start_date >='#{start_date}'
																 AND s.start_date <= '#{end_date}'
																 AND obs.concept_id = #{cause_concept_id}
																 AND p.program_id = #{@@program_id}
																 AND obs.value_coded = #{tb_concept_id}
																 GROUP BY patient_id")
=end
	end

	def kaposis_sarcoma(start_date = @start_date, end_date = @end_date)
		tb_concept_id = ConceptName.find_by_name("KAPOSIS SARCOMA").concept_id
		self.patients_with_start_cause(start_date,end_date, concept_id)
	end

	def total_alive_and_on_art
=begin
		on_art_concept_name = ConceptName.find_all_by_name('On antiretrovirals')
		state = ProgramWorkflowState.find(
		  :first,
		  :conditions => ["concept_id IN (?)",
					      on_art_concept_name.map{|c|c.concept_id}]
		).program_workflow_state_id

		PatientState.find_by_sql("SELECT * FROM (
			SELECT s.patient_program_id, patient_id,patient_state_id,start_date,
				   n.name name,state
			FROM patient_state s
			LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id
			LEFT JOIN program_workflow pw ON pw.program_id = p.program_id
			LEFT JOIN program_workflow_state w ON w.program_workflow_id = pw.program_workflow_id
			AND w.program_workflow_state_id = s.state
			LEFT JOIN concept_name n ON w.concept_id = n.concept_id
			WHERE p.voided = 0 AND s.voided = 0
			AND (s.start_date >= '#{@@first_registration_date}'
			AND s.start_date <= '#{@end_date}')
			AND p.program_id = #{@@program_id}
			ORDER BY patient_state_id DESC, start_date DESC
		  ) K
		  GROUP BY K.patient_id HAVING (state = #{state})
		  ORDER BY K.patient_state_id DESC, K.start_date DESC")
=end
    
    PatientProgram.find_by_sql("SELECT patient_id, current_state_for_program(patient_id, 1, '#{@end_date}') AS state FROM earliest_start_date
										WHERE earliest_start_date <=  '#{@end_date}'
										HAVING state = 7")
	end

	def died_total
		self.outcomes_total('PATIENT DIED')
	end
  
	def total_number_of_dead_patients

		PatientProgram.find_by_sql("SELECT * FROM person p LEFT JOIN earliest_start_date e ON p.person_id = e.patient_id
										WHERE dead = 1
											AND earliest_start_date <=  '#{@end_date}'")
    
    #PatientProgram.find_by_sql("SELECT patient_id, current_state_for_program(patient_id, 1, '#{@end_date}') AS state FROM earliest_start_date
		#								WHERE earliest_start_date <=  '#{@end_date}'
		#								HAVING state = 3")
	end

	def total_number_of_died_within_range(min_days = 0, max_days = 0)
		PatientProgram.find_by_sql("SELECT person_id, birthdate, death_date, earliest_start_date, DATEDIFF(death_date, earliest_start_date) AS days 
										FROM person p 
											LEFT JOIN earliest_start_date e ON p.person_id = e.patient_id
										WHERE dead = 1
											AND earliest_start_date <=  '#{@end_date}'
										HAVING days >= #{min_days}
										AND days < #{max_days}")
	end

	def transferred_out_patients
		#self.outcomes_total('PATIENT TRANSFERRED OUT').length
		PatientProgram.find_by_sql("SELECT patient_id, current_state_for_program(patient_id, 1, '#{@end_date}') AS state FROM earliest_start_date 
										WHERE earliest_start_date <=  '#{@end_date}'
										HAVING state = 2")
	end

	def art_defaulted_patients
		PatientProgram.find_by_sql("SELECT patient_id, current_defaulter(patient_id, '#{@end_date}') AS def FROM earliest_start_date 
										WHERE earliest_start_date <=  '#{@end_date}'
										HAVING def = 1")
	end

	def art_stopped_patients
		PatientProgram.find_by_sql("SELECT patient_id, current_state_for_program(patient_id, 1, '#{@end_date}') AS state FROM earliest_start_date 
										WHERE earliest_start_date <=  '#{@end_date}'
										HAVING state = 6")
	end

	def tb_status
		tb_status_hash = {} ; status = []
		tb_status_hash['TB STATUS'] = {'Unknown' => 0,'Suspected' => 0,'Not Suspected' => 0,'On Treatment' => 0,'Not on treatment' => 0} 
		tb_status_concept_id = ConceptName.find_by_name('TB STATUS').concept_id
		hiv_clinic_consultation_encounter_id = EncounterType.find_by_name('HIV CLINIC CONSULTATION').id
=begin
    status = PatientState.find_by_sql("SELECT * FROM (
                          SELECT e.patient_id,n.name tbstatus,obs_datetime,e.encounter_datetime,s.state
                          FROM patient_state s
                          LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id   
                          
                          LEFT JOIN encounter e ON e.patient_id = p.patient_id
                          
                          LEFT JOIN obs ON obs.encounter_id = e.encounter_id
                          LEFT JOIN concept_name n ON obs.value_coded = n.concept_id
                          WHERE p.voided = 0
                          AND s.voided = 0
                          AND obs.obs_datetime = e.encounter_datetime
                          AND (s.start_date >= '#{start_date}'
                          AND s.start_date <= '#{end_date}')
                          AND obs.concept_id = #{tb_status_concept_id}
                          AND e.encounter_type = #{hiv_clinic_consultation_encounter_id}
                          AND p.program_id = #{@@program_id}
                          ORDER BY e.encounter_datetime DESC, patient_state_id DESC , start_date DESC) K
                          GROUP BY K.patient_id
                          ORDER BY K.encounter_datetime DESC , K.obs_datetime DESC")
=end      
		states = Hash.new()                    
		status = PatientState.find_by_sql("SELECT e.patient_id, current_value_for_obs(e.patient_id, #{hiv_clinic_consultation_encounter_id}, #{tb_status_concept_id}, '#{end_date}') AS obs_value 
												FROM earliest_start_date e
												WHERE earliest_start_date <= '#{end_date}'").map{ |state| states[state.patient_id] = state.obs_value }

 
		tb_not_suspected_id = ConceptName.find_by_name('TB NOT SUSPECTED').concept_id
		tb_suspected_id = ConceptName.find_by_name('TB SUSPECTED').concept_id
		tb_confirmed_on_treatment_id = ConceptName.find_by_name('CONFIRMED TB ON TREATMENT').concept_id
		tb_confirmed_not_on_treatment_id = ConceptName.find_by_name('CONFIRMED TB NOT ON TREATMENT').concept_id

		tb_status_hash['TB STATUS']['Not Suspected'] = []
		tb_status_hash['TB STATUS']['Suspected'] = []
		tb_status_hash['TB STATUS']['On Treatment'] = []
		tb_status_hash['TB STATUS']['Not on treatment'] = []
		tb_status_hash['TB STATUS']['Unknown'] = []

		( states || [] ).each do | patient_id, state |
			if state == tb_not_suspected_id
				tb_status_hash['TB STATUS']['Not Suspected'] << patient_id
			elsif state == tb_suspected_id
				tb_status_hash['TB STATUS']['Suspected'] << patient_id
			elsif state == tb_confirmed_on_treatment_id
				tb_status_hash['TB STATUS']['On Treatment'] << patient_id
			elsif state == tb_confirmed_not_on_treatment_id
				tb_status_hash['TB STATUS']['Not on treatment'] << patient_id
			else
				tb_status_hash['TB STATUS']['Unknown'] << patient_id
			end
		end
		tb_status_hash
	end

  def outcomes_total(outcome)
    on_art_concept_name = ConceptName.find_all_by_name(outcome)
    state = ProgramWorkflowState.find(
      :first,
      :conditions => ["concept_id IN (?)",
                      on_art_concept_name.map{|c|c.concept_id}]
    ).program_workflow_state_id

    PatientState.find_by_sql("SELECT * FROM (
        SELECT s.patient_program_id, patient_id, patient_state_id, start_date,
               n.name name, state, p.date_enrolled AND date_enrolled
        FROM patient_state s
        LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id
        LEFT JOIN program_workflow pw ON pw.program_id = p.program_id
        LEFT JOIN program_workflow_state w ON w.program_workflow_id = pw.program_workflow_id
        AND w.program_workflow_state_id = s.state
        LEFT JOIN concept_name n ON w.concept_id = n.concept_id
        WHERE p.voided = 0 AND s.voided = 0
        AND (s.start_date >= '#{@@first_registration_date}'
        AND s.start_date <= '#{@end_date}')
        AND p.program_id = #{@@program_id}
        ORDER BY patient_state_id DESC, start_date DESC
      ) K
      GROUP BY K.patient_id HAVING (state = #{state})
      ORDER BY K.patient_state_id DESC, K.start_date DESC")
  end

=begin
	def death_dates(start_date = @start_date, end_date = @end_date)
		start_date_death_date = [] 

		first_month = [] ; second_month = [] ; third_month = [] ; after_third_month = []

		first_month_date = [start_date.to_date,(start_date.to_date + 1.month)]
		second_month_date = [first_month_date[1],first_month_date[1] + 1.month]
		third_month_date = [second_month_date[1],second_month_date[1] + 1.month]

		( self.died_total || [] ).each do | state |
		  if (state.date_enrolled.to_date >= first_month_date[0]  and state.date_enrolled.to_date <= first_month_date[1] )
			  first_month << state
		  elsif (state.date_enrolled.to_date >= second_month_date[0]  and state.date_enrolled.to_date <= second_month_date[1] )
			  second_month << state
		  elsif (state.date_enrolled.to_date >= third_month_date[0]  and state.date_enrolled.to_date <= third_month_date[1] )
			  third_month << state
		  elsif (state.date_enrolled.to_date > third_month_date[1] )
			  after_third_month << state
		  end
		end
		[first_month, second_month, third_month, after_third_month]
	end
=end

	# Get patients reinitiated on art count
	def patients_reinitiated_on_art_ever
		Observation.find(:all, :joins => [:encounter], :conditions => ["concept_id = ? AND value_coded IN (?) AND encounter.voided = 0 \
			AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') <= ?", ConceptName.find_by_name("EVER RECEIVED ART").concept_id,
			ConceptName.find(:all, :conditions => ["name = 'YES'"]).collect{|c| c.concept_id},
			@end_date.to_date.strftime("%Y-%m-%d")]).length rescue 0
	end

	def patients_reinitiated_on_arts
		Observation.find(:all, :joins => [:encounter], :conditions => ["concept_id = ? AND value_coded IN (?) AND encounter.voided = 0 \
			AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') >= ? AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') <= ?",
			ConceptName.find_by_name("EVER RECEIVED ART").concept_id,
			ConceptName.find(:all, :conditions => ["name = 'YES'"]).collect{|c| c.concept_id},
			@start_date.to_date.strftime("%Y-%m-%d"), @end_date.to_date.strftime("%Y-%m-%d")]).length rescue 0
	end

  def patients_reinitiated_on_arts_ids
    Observation.find(:all, :joins => [:encounter], :conditions => ["concept_id = ? AND value_coded IN (?) AND encounter.voided = 0 \
        AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') >= ? AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') <= ?",
        ConceptName.find_by_name("EVER RECEIVED ART").concept_id,
        ConceptName.find(:all, :conditions => ["name = 'YES'"]).collect{|c| c.concept_id},
        @start_date.to_date.strftime("%Y-%m-%d"), @end_date.to_date.strftime("%Y-%m-%d")]).map{|patient| patient.person_id}
  end

  def outcomes(start_date=@start_date, end_date=@end_date, outcome_end_date=@end_date, program_id = @@program_id, min_age=nil, max_age=nil,states = [])

    if min_age or max_age
      conditions = "AND TRUNCATE(DATEDIFF(p.date_enrolled, person.birthdate)/365,0) >= #{min_age}
                    AND TRUNCATE(DATEDIFF(p.date_enrolled, person.birthdate)/365,0) <= #{max_age}"
    end

    PatientState.find_by_sql("SELECT * FROM (
        SELECT s.patient_program_id, patient_id,patient_state_id,start_date,
               n.name name,state
        FROM patient_state s
        INNER JOIN patient_program p ON p.patient_program_id = s.patient_program_id
        INNER JOIN program_workflow pw ON pw.program_id = p.program_id
        INNER JOIN program_workflow_state w ON w.program_workflow_id = pw.program_workflow_id
                   AND w.program_workflow_state_id = s.state
        INNER JOIN concept_name n ON w.concept_id = n.concept_id
        INNER JOIN person ON person.person_id = p.patient_id
        WHERE p.voided = 0 AND s.voided = 0 #{conditions}
        AND (patient_start_date(patient_id) >= '#{start_date}'
        AND patient_start_date(patient_id) <= '#{end_date}')
        AND p.program_id = #{program_id}
        AND s.start_date <= '#{outcome_end_date}'
        ORDER BY patient_id DESC, patient_state_id DESC, start_date DESC
      ) K
      GROUP BY patient_id
      ORDER BY K.patient_state_id DESC , K.start_date DESC").map do |state|
        states << [state.patient_id , state.name]
      end
  end

  
  def first_registration_date
    @@first_registration_date
  end
  
  def regimens(start_date = @start_date, end_date = @end_date)
    regimens = []
    regimen_hash = {}
    @patients_alive_and_on_art ||= self.total_alive_and_on_art
    patient_ids = @patients_alive_and_on_art.map(&:patient_id)

    regimem_given_concept = ConceptName.find_by_name('ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT')
=begin
    PatientProgram.find_by_sql("SELECT patient_id , value_coded regimen_id, value_text regimen ,
                                age(LEFT(person.birthdate,10),LEFT(obs.obs_datetime,10),
                                LEFT(person.date_created,10),person.birthdate_estimated) person_age_at_drug_dispension  
                                FROM obs 
                                INNER JOIN patient_program p ON p.patient_id = obs.person_id
                                INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                                INNER JOIN person ON person.person_id = p.patient_id
                                WHERE p.program_id = #{end_date} AND obs.concept_id = #{regimem_given_concept.concept_id}
                                AND patient_start_date(patient_id) >= '#{start_date}' AND patient_start_date(patient_id) <= '#{end_date}' 
                                GROUP BY patient_id 
                                ORDER BY obs.obs_datetime DESC")
=end


		PatientProgram.find_by_sql("SELECT patient_id , obs.value_coded regimen_id, obs.value_text regimen ,
																	 age(LEFT(person.birthdate,10),LEFT(obs.obs_datetime,10),
																	 LEFT(person.date_created,10),person.birthdate_estimated) person_age_at_drug_dispension 
																	 FROM obs 
																	 LEFT JOIN patient_program p ON p.patient_id = obs.person_id
																	 LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
																	 LEFT JOIN person ON person.person_id = p.patient_id
																	 WHERE p.program_id = #{@@program_id} AND obs.concept_id = #{regimem_given_concept.concept_id}
																	 AND s.start_date >= '#{start_date}' AND s.start_date <= '#{end_date}'
																	 AND p.patient_id IN (#{patient_ids.join(',')})
																	 GROUP BY patient_id 
																	 ORDER BY obs.obs_datetime DESC ").each do | value | 
                                  regimens << [value.regimen_id, 
                                               value.regimen,
                                               value.person_age_at_drug_dispension
                                              ]
                                end
    ( regimens || [] ).each do | regimen_id, regimen , patient_age |
      age = patient_age.to_i 
      regimen_name = ConceptName.find_by_concept_id(regimen_id).concept.shortname rescue nil
      if regimen_name.blank?
        regimen_name = ConceptName.find_by_concept_id(regimen_id).concept.fullname 
      end

      regimen_name = cohort_regimen_name(regimen_name,age)

      if regimen_hash[regimen_name].blank?
        regimen_hash[regimen_name] = 0
      end
      regimen_hash[regimen_name]+=1
    end
    regimen_hash
  end
  
  def regimens_with_patient_ids(start_date = @start_date, end_date = @end_date)
    regimens = []
    regimen_hash = {}

    regimem_given_concept = ConceptName.find_by_name('ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT')
    PatientProgram.find_by_sql("SELECT patient_id , value_coded regimen_id, value_text regimen ,
                                age(LEFT(person.birthdate,10),LEFT(obs.obs_datetime,10),
                                LEFT(person.date_created,10),person.birthdate_estimated) person_age_at_drug_dispension  
                                FROM obs 
                                INNER JOIN patient_program p ON p.patient_id = obs.person_id
                                INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                                INNER JOIN person ON person.person_id = p.patient_id
                                WHERE p.program_id = #{@@program_id}
                                AND obs.concept_id = #{regimem_given_concept.concept_id}
                                AND patient_start_date(patient_id) >= '#{start_date}'
                                AND patient_start_date(patient_id) <= '#{end_date}' 
                                GROUP BY patient_id 
                                ORDER BY obs.obs_datetime DESC").each do | value |
                                  if value.regimen.blank?
																		value.regimen = ConceptName.find_by_concept_id(value.regimen_id).concept.shortname								
		                                regimens << [value.regimen_id, 
		                                             value.regimen,
		                                             value.person_age_at_drug_dispension
		                                            ]
		                              else
		                              	regimens << [value.regimen_id, 
		                                             value.regimen,
		                                             value.person_age_at_drug_dispension
		                                            ]
		                              end
                                end
  end

  def patients_reinitiated_on_art(start_date = @start_date, end_date = @end_date)
    patients = []
    
		no_concept = ConceptName.find_by_name('NO').concept_id
    date_art_last_taken_concept = ConceptName.find_by_name('DATE ART LAST TAKEN').concept_id

    taken_arvs_concept = ConceptName.find_by_name('HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS').concept_id
    
    defaulted = ConceptName.find_all_by_name("DEFAULTED")
    defaulted_state = ProgramWorkflowState.find(
      :first,
      :conditions => ["concept_id IN (?)",
                      defaulted.map{|c|c.concept_id}]
    ).program_workflow_state_id

		treatment_stopped = ConceptName.find_all_by_name("TREATMENT STOPPED")
    treatment_stopped_state = ProgramWorkflowState.find(
      :first,
      :conditions => ["concept_id IN (?)",
                      treatment_stopped.map{|c|c.concept_id}]
    ).program_workflow_state_id
    
   	PatientProgram.find_by_sql("SELECT patient_id , value_datetime date_art_last_taken,obs_datetime visit_date,value_coded,obs.concept_id concept_id  
                                FROM obs 
                                LEFT JOIN patient_program p ON p.patient_id = obs.person_id
                                LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                                WHERE p.program_id = #{@@program_id} 
                                AND (obs.concept_id = #{date_art_last_taken_concept}
                                OR obs.concept_id = #{taken_arvs_concept})
                                AND patient_start_date(patient_id) >= '#{start_date}'
                                AND patient_start_date(patient_id) <= '#{end_date}'
                                GROUP BY patient_id
                                ORDER BY obs.obs_datetime DESC").map do |ob| 
                                	if ob.concept_id.to_s == date_art_last_taken_concept.to_s
																		patient_program_id = PatientProgram.find_by_patient_id(ob.patient_id).patient_program_id
																		state = PatientState.find(:all, :conditions => ["patient_program_id = #{patient_program_id} AND end_date IS NOT NULL"], :order => 'date_created ASC').last rescue 0 
																		if !state.blank?
																			if (state.state == "#{defaulted_state}" || state.state == "#{treatment_stopped_state}")
																			
																				unless 4 >= ((ob.visit_date.to_date - ob.date_art_last_taken.to_date) / 7).to_i
																					patients << ob
																				end
																			end
																		end
																	elsif ob.value_coded.to_s == no_concept.to_s
																	  patients << ob
																	end
                                end
    return patients

  end










	def adherence(start_date = @start_date, end_date = @end_date)

		#loop through each patient with adherence encounter
		art_adherence = EncounterType.find_by_name('ART ADHERENCE').id
		pills_left_ids = [ConceptName.find_by_name("AMOUNT OF DRUG BROUGHT TO CLINIC").concept_id,
											  ConceptName.find_by_name("AMOUNT OF DRUG REMAINING AT HOME").concept_id]
		
		encounters = Encounter.find(:all, :conditions => ["encounter_type = #{art_adherence}"], :limit => 500)#

		counter = 0
		encounters.map do |adherence|

			orders = PatientService.drug_given_before(adherence.patient, adherence.encounter_datetime)

			orders.map do |order| 
				amount_brought_to_clinic = 0
				adherence.observations.map do |obs|
					if pills_left_ids.include?(obs.concept_id) && order.order_id == obs.order_id
						amount_brought_to_clinic += obs.answer_string.to_i
					end

				end

				num_days = (adherence.encounter_datetime.to_date - order.start_date.to_date).to_i#/ (1000 * 60 * 60 * 24)

				if order.drug_order.quantity 
					order_quantity = order.drug_order.quantity
				else
					order_quantity = 0
				end

				expected_amount_remaining = (order_quantity - (num_days * order.drug_order.equivalent_daily_dose.to_i))

				if expected_amount_remaining == amount_brought_to_clinic
		    	doses_missed = 0
		    else
		    	doses_missed = ((expected_amount_remaining - amount_brought_to_clinic) / order.drug_order.equivalent_daily_dose.to_i)#.to_i
		    	if doses_missed < 0
		    		doses_missed = doses_missed * -1
		    	else
		    		doses_missed
		    	end
		    end
		    
		    observation = Observation.new
				observation.person_id = adherence.patient_id
				observation.encounter_id = adherence.encounter_id
				observation.concept_id = ConceptName.find_by_name("MISSED HIV DRUG CONSTRUCT").concept_id
				observation.obs_datetime = adherence.encounter_datetime
				observation.value_numeric = doses_missed.to_i
				observation.order_id = order.order_id
				observation.location_id = adherence.location_id
				if observation.save
					counter += 1
				end
			end
		end
		return counter
	end


  def kaposis_sarcoma(start_date = @start_date, end_date = @end_date)
    tb_concept_id = ConceptName.find_by_name("KAPOSIS SARCOMA").concept_id
    self.patients_with_start_cause(start_date, end_date, tb_concept_id)
  end

  def current_episode_of_tb(start_date = @start_date, end_date = @end_date)
    tb_concept_id = ConceptName.find_by_name("EXTRAPULMONARY TUBERCULOSIS (EPTB)").concept_id
    self.patients_with_start_cause(start_date, end_date, tb_concept_id)
  end



  
  def tb_status_with_patient_ids
    tb_status_hash = {} ; status = []
    tb_status_hash['TB STATUS'] = {'Unknown' => 0,'Suspected' => 0,'Not Suspected' => 0,'On Treatment' => 0,'Not on treatment' => 0} 
    tb_status_concept_id = ConceptName.find_by_name('TB STATUS').concept_id
    hiv_clinic_consultation_encounter_id = EncounterType.find_by_name('HIV CLINIC CONSULTATION').id
=begin
    status = PatientState.find_by_sql("SELECT * FROM (
                          SELECT e.patient_id,n.name tbstatus,obs_datetime,e.encounter_datetime,s.state
                          FROM patient_state s
                          LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id   
                          LEFT JOIN encounter e ON e.patient_id = p.patient_id
                          LEFT JOIN obs ON obs.encounter_id = e.encounter_id
                          LEFT JOIN concept_name n ON obs.value_coded = n.concept_id
                          WHERE p.voided = 0
                          AND s.voided = 0
                          AND obs.obs_datetime = e.encounter_datetime
                          AND (s.start_date >= '#{start_date}'
                          AND s.start_date <= '#{end_date}')
                          AND obs.concept_id = #{tb_status_concept_id}
                          AND e.encounter_type = #{hiv_clinic_consultation_encounter_id}
                          AND p.program_id = #
{@@program_id}
                          ORDER BY e.encounter_datetime DESC, patient_state_id DESC , start_date DESC) K
                          GROUP BY K.patient_id
                          ORDER BY K.encounter_datetime DESC , K.obs_datetime DESC")
=end
		status = PatientProgram.find_by_sql("SELECT e.patient_id, current_value_for_obs(e.patient_id, #{hiv_clinic_consultation_encounter_id}, #{tb_status_concept_id}, '#{end_date}') AS obs_value 
												FROM earliest_start_date e
												WHERE earliest_start_date <= '#{end_date}'")
  end

  def side_effect_patients(start_date = @start_date, end_date = @end_date)
    side_effect_concept_ids =[ConceptName.find_by_name('PERIPHERAL NEUROPATHY').concept_id,
                              ConceptName.find_by_name('HEPATITIS').concept_id,
                              ConceptName.find_by_name('SKIN RASH').concept_id,
                              ConceptName.find_by_name('JAUNDICE').concept_id]

    encounter_type = EncounterType.find_by_name('HIV CLINIC CONSULTATION')
    concept_id = ConceptName.find_by_name('SYMPTOM PRESENT').concept_id

    encounter_ids = Encounter.find(:all,:conditions => ["encounter_type = ? 
                    AND (patient_start_date(patient_id) >= '#{start_date}'
                    AND patient_start_date(patient_id) <= '#{end_date}')
                    AND (encounter_datetime >= '#{start_date}'
                    AND encounter_datetime <= '#{end_date}')",
                    encounter_type.id],:group => 'patient_id',:order => 'encounter_datetime DESC').map{| e | e.encounter_id }

    Observation.find(:all,
                     :conditions => ["encounter_id IN (#{encounter_ids.join(',')})
                     AND concept_id = ? 
                     AND value_coded IN (#{side_effect_concept_ids.join(',')})",concept_id],
                     :group =>'person_id').length
  end

  def patients_with_side_effects(start_date = @start_date, end_date = @end_date)
		side_effect_concept_ids =[ConceptName.find_by_name('PERIPHERAL NEUROPATHY').concept_id,
                              ConceptName.find_by_name('HEPATITIS').concept_id,
                              ConceptName.find_by_name('SKIN RASH').concept_id,
                              ConceptName.find_by_name('JAUNDICE').concept_id]

    hiv_clinic_consultation_encounter_id = EncounterType.find_by_name('HIV CLINIC CONSULTATION').id
    symptom_present_concept_id = ConceptName.find_by_name('SYMPTOM PRESENT').concept_id

		on_art_concept_name = ConceptName.find_all_by_name('On antiretrovirals')

    patient_ids = @patients_alive_and_on_art.map(&:patient_id)

		state = ProgramWorkflowState.find(
			:first,
			:conditions => ["concept_id IN (?)",
				on_art_concept_name.map{|c|c.concept_id}]
			).program_workflow_state_id

		PatientState.find_by_sql("SELECT e1.patient_id AS patient_id,
                              DATE(MAX(e1.encounter_datetime)) AS latest_visit_date,
                              e1.encounter_datetime
                              FROM encounter e1
                                  INNER JOIN obs o
                                      ON e1.encounter_id = o.encounter_id
                                      AND o.concept_id = #{symptom_present_concept_id} AND o.voided = 0
                              WHERE e1.encounter_type = #{hiv_clinic_consultation_encounter_id}
                                  AND e1.voided = 0
                                  AND o.value_coded IN (#{side_effect_concept_ids.join(',')})
                                  AND e1.patient_id IN (#{patient_ids.join(',')})
                              GROUP BY e1.patient_id
                              HAVING DATE(e1.encounter_datetime) = latest_visit_date")
=begin
PatientProgram.find_by_sql("SELECT patient_id FROM patient_program p
	                        INNER JOIN patient_state s USING (patient_program_id)
	                        WHERE p.voided = 0
	                        AND s.voided = 0
	                        AND program_id = #{@@program_id}
	                        AND s.state = #{state}
	                        AND patient_start_date(patient_id) >= '#{start_date}'
	                        AND patient_start_date(patient_id) <= '#{end_date}'
	                        GROUP BY patient_id ORDER BY date_enrolled")#.length rescue 0
=end
	end

  private

  def cohort_regimen_name(name , age)
    case name
      when 'd4T/3TC/NVP'
        return 'A1' if age > 14
        return 'P1'
      when 'd4T/3TC + d4T/3TC/NVP (Starter pack)'
        return 'A1' if age > 14
        return 'P1'
      when 'AZT/3TC/NVP'
        return 'A2' if age > 14
        return 'P2'
      when 'AZT/3TC + AZT/3TC/NVP (Starter pack)'
        return 'A2' if age > 14
        return 'P2'
      when 'd4T/3TC/EFV'
        return 'A3' if age > 14
        return 'P3'
      when 'AZT/3TC+EFV'
        return 'A4' if age > 14
        return 'P4'
      when 'TDF/3TC/EFV'
        return 'A5' if age > 14
        return 'P5'
      when 'TDF/3TC+NVP'
        return 'A6' if age > 14
        return 'P6'
      when 'TDF/3TC+LPV/r'
        return 'A7' if age > 14
        return 'P7'
      when 'AZT/3TC+LPV/r'
        return 'A8' if age > 14
        return 'P8'
      when 'ABC/3TC+LPV/r'
        return 'A9' if age > 14
        return 'P9'
      else
        return 'UNKNOWN ANTIRETROVIRAL DRUG'
    end
  end
end

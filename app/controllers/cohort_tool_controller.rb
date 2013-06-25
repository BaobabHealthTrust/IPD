class CohortToolController < ApplicationController

  def select
    @cohort_quarters  = [""]
    @report_type      = params[:report_type]
    @header 	        = params[:report_type] rescue ""
    @page_destination = ("/" + params[:dashboard].gsub("_", "/")) rescue ""

    if @report_type == "in_arv_number_range"
      @arv_number_start = params[:arv_number_start]
      @arv_number_end   = params[:arv_number_end]
    end

  start_date  = PatientService.initial_encounter.encounter_datetime rescue Date.today

  end_date    = Date.today

  @cohort_quarters  += Report.generate_cohort_quarters(start_date, end_date)
  end

  def reports
    session[:list_of_patients] = nil
    if params[:report]
      case  params[:report_type]
        when "visits_by_day"
          redirect_to :action   => "visits_by_day",
                      :name     => params[:report],
                      :pat_name => "Visits by day",
                      :quarter  => params[:report].gsub("_"," ")
        return

        when "non_eligible_patients_in_cohort"
          date = Report.generate_cohort_date_range(params[:report])

          redirect_to :action       => "non_eligible_patients_in_art",
                      :controller   => "report",
                      :start_date   => date.first.to_s,
                      :end_date     => date.last.to_s,
                      :id           => "start_reason_other",
                      :report_type  => "non_eligible patients in: #{params[:report]}"
        return

        when "out_of_range_arv_number"
          redirect_to :action           => "out_of_range_arv_number",
                      :arv_end_number   => params[:arv_end_number],
                      :arv_start_number => params[:arv_start_number],
                      :quarter          => params[:report].gsub("_"," "),
                      :report_type      => params[:report_type]
        return

        when "data_consistency_check"
          redirect_to :action       => "data_consistency_check",
                      :quarter      => params[:report],
                      :report_type  => params[:report_type]
        return

        when "summary_of_records_that_were_updated"
          redirect_to :action   => "records_that_were_updated",
                      :quarter  => params[:report].gsub("_"," ")
        return

        when "adherence_histogram_for_all_patients_in_the_quarter"
          redirect_to :action   => "adherence",
                      :quarter  => params[:report].gsub("_"," ")
        return

        when "patients_with_adherence_greater_than_hundred"
          redirect_to :action  => "patients_with_adherence_greater_than_hundred",
                      :quarter => params[:report].gsub("_"," ")
        return

        when "patients_with_multiple_start_reasons"
          redirect_to :action       => "patients_with_multiple_start_reasons",
                      :quarter      => params[:report],
                      :report_type  => params[:report_type]
        return

        when "dispensations_without_prescriptions"
          redirect_to :action       => "dispensations_without_prescriptions",
                      :quarter      => params[:report],
                      :report_type  => params[:report_type]
        return

        when "prescriptions_without_dispensations"
          redirect_to :action       => "prescriptions_without_dispensations",
                      :quarter      => params[:report],
                      :report_type  => params[:report_type]
        return

        when "drug_stock_report"
          start_date  = "#{params[:start_year]}-#{params[:start_month]}-#{params[:start_day]}"
          end_date    = "#{params[:end_year]}-#{params[:end_month]}-#{params[:end_day]}"

          if end_date.to_date < start_date.to_date
            redirect_to :controller   => "cohort_tool",
                        :action       => "select",
                        :report_type  =>"drug_stock_report" and return
          end rescue nil

          redirect_to :controller => "drug",
                      :action     => "report",
                      :start_date => start_date,
                      :end_date   => end_date,
                      :quarter    => params[:report].gsub("_"," ")
        return
      end
    end
  end

  def records_that_were_updated
    @quarter    = params[:quarter]

    date_range  = Report.generate_cohort_date_range(@quarter)
    @start_date = date_range.first
    @end_date   = date_range.last

    @encounters = records_that_were_corrected(@quarter)

    render :layout => false
  end

  def records_that_were_corrected(quarter)

    date        = Report.generate_cohort_date_range(quarter)
    start_date  = (date.first.to_s  + " 00:00:00")
    end_date    = (date.last.to_s   + " 23:59:59")

    voided_records = {}

    other_encounters = Encounter.find_by_sql("SELECT encounter.* FROM encounter
                        INNER JOIN obs ON encounter.encounter_id = obs.encounter_id
                        WHERE ((encounter.encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}'))
                        GROUP BY encounter.encounter_id
                        ORDER BY encounter.encounter_type, encounter.patient_id")

    drug_encounters = Encounter.find_by_sql("SELECT encounter.* as duration FROM encounter
                        INNER JOIN orders ON encounter.encounter_id = orders.encounter_id
                        WHERE ((encounter.encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}'))
                        ORDER BY encounter.encounter_type")

    voided_encounters = []
    other_encounters.delete_if { |encounter| voided_encounters << encounter if (encounter.voided == 1)}

    voided_encounters.map do |encounter|
      patient           = Patient.find(encounter.patient_id)
      patient_bean = PatientService.get_patient(patient.person)

      new_encounter  = other_encounters.reduce([])do |result, e|
        result << e if( e.encounter_datetime.strftime("%d-%m-%Y") == encounter.encounter_datetime.strftime("%d-%m-%Y")&&
                        e.patient_id      == encounter.patient_id &&
                        e.encounter_type  == encounter. encounter_type)
        result
      end

      new_encounter = new_encounter.last

      next if new_encounter.nil?

      voided_observations = voided_observations(encounter)
      changed_to    = changed_to(new_encounter)
      changed_from  = changed_from(voided_observations)

      if( voided_observations && !voided_observations.empty?)
          voided_records[encounter.id] = {
              "id"              => patient.patient_id,
              "arv_number"      => patient_bean.arv_number,
              "name"            => patient_bean.name,
              "national_id"     => patient_bean.national_id,
              "encounter_name"  => encounter.name,
              "voided_date"     => encounter.date_voided,
              "reason"          => encounter.void_reason,
              "change_from"     => changed_from,
              "change_to"       => changed_to
            }
      end
    end

    voided_treatments = []
    drug_encounters.delete_if { |encounter| voided_treatments << encounter if (encounter.voided == 1)}

    voided_treatments.each do |encounter|

      patient           = Patient.find(encounter.patient_id)
      patient_bean = PatientService.get_patient(patient.person)
      
      orders            = encounter.orders
      changed_from      = ''
      changed_to        = ''

     new_encounter  =  drug_encounters.reduce([])do |result, e|
        result << e if( e.encounter_datetime.strftime("%d-%m-%Y") == encounter.encounter_datetime.strftime("%d-%m-%Y")&&
                        e.patient_id      == encounter.patient_id &&
                        e.encounter_type  == encounter. encounter_type)
          result
        end

      new_encounter = new_encounter.last

      next if new_encounter.nil?
      changed_from  += "Treatment: #{voided_orders(new_encounter).to_s.gsub!(":", " =>")}</br>"
      changed_to    += "Treatment: #{encounter.to_s.gsub!(":", " =>") }</br>"

      if( orders && !orders.empty?)
        voided_records[encounter.id]= {
            "id"              => patient.patient_id,
            "arv_number"      => patient_bean.arv_number,
            "name"            => patient_bean.name,
            "national_id"     => patient_bean.national_id,
            "encounter_name"  => encounter.name,
            "voided_date"     => encounter.date_voided,
            "reason"          => encounter.void_reason,
            "change_from"     => changed_from,
            "change_to"       => changed_to
        }
      end

    end

    show_tabuler_format(voided_records)
  end

   def show_tabuler_format(records)

    patients = {}

    records.each do |key,value|

      sorted_values = sort(value)

      patients["#{key},#{value['id']}"] = sorted_values
    end

    patients
  end

  def sort(values)
    name              = ''
    patient_id        = ''
    arv_number        = ''
    national_id       = ''
    encounter_name    = ''
    voided_date       = ''
    reason            = ''
    obs_names         = ''
    changed_from_obs  = {}
    changed_to_obs    = {}
    changed_data      = {}

    values.each do |value|
      value_name =  value.first
      value_data =  value.last

      case value_name
        when "id"
          patient_id = value_data
        when "arv_number"
          arv_number = value_data
        when "name"
          name = value_data
        when "national_id"
          national_id = value_data
        when "encounter_name"
          encounter_name = value_data
        when "voided_date"
          voided_date = value_data
        when "reason"
          reason = value_data
        when "change_from"
          value_data.split("</br>").each do |obs|
            obs_name  = obs.split(':')[0].strip
            obs_value = obs.split(':')[1].strip rescue ''

            changed_from_obs[obs_name] = obs_value
          end unless value_data.blank?
        when "change_to"

          value_data.split("</br>").each do |obs|
            obs_name  = obs.split(':')[0].strip
            obs_value = obs.split(':')[1].strip rescue ''

            changed_to_obs[obs_name] = obs_value
          end unless value_data.blank?
      end
    end

    changed_from_obs.each do |a,b|
      changed_to_obs.each do |x,y|

        if (a == x)
          next if b == y
          changed_data[a] = "#{b} to #{y}"

          changed_from_obs.delete(a)
          changed_to_obs.delete(x)
        end
      end
    end

    changed_to_obs.each do |a,b|
      changed_from_obs.each do |x,y|
        if (a == x)
          next if b == y
          changed_data[a] = "#{b} to #{y}"

          changed_to_obs.delete(a)
          changed_from_obs.delete(x)
        end
      end
    end

    changed_data.each do |k,v|
      from  = v.split("to")[0].strip rescue ''
      to    = v.split("to")[1].strip rescue ''

      if obs_names.blank?
        obs_names = "#{k}||#{from}||#{to}||#{voided_date}||#{reason}"
      else
        obs_names += "</br>#{k}||#{from}||#{to}||#{voided_date}||#{reason}"
      end
    end

    results = {
        "id"              => patient_id,
        "arv_number"      => arv_number,
        "name"            => name,
        "national_id"     => national_id,
        "encounter_name"  => encounter_name,
        "voided_date"     => voided_date,
        "obs_name"        => obs_names,
        "reason"          => reason
      }

    results
  end

  def changed_from(observations)
    changed_obs = ''

    observations.collect do |obs|
      ["value_coded","value_datetime","value_modifier","value_numeric","value_text"].each do |value|
        case value
          when "value_coded"
            next if obs.value_coded.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_datetime"
            next if obs.value_datetime.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_numeric"
            next if obs.value_numeric.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_text"
            next if obs.value_text.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_modifier"
            next if obs.value_modifier.blank?
            changed_obs += "#{obs.to_s}</br>"
        end
      end
    end

    changed_obs.gsub("00:00:00 +0200","")[0..-6]
  end

  def changed_to(enc)
    encounter_type = enc.encounter_type

    encounter = Encounter.find(:first,
                 :joins       => "INNER JOIN obs ON encounter.encounter_id=obs.encounter_id",
                 :conditions  => ["encounter_type=? AND encounter.patient_id=? AND Date(encounter.encounter_datetime)=?",
                                  encounter_type,enc.patient_id, enc.encounter_datetime.to_date],
                 :group       => "encounter.encounter_type",
                 :order       => "encounter.encounter_datetime DESC")

    observations = encounter.observations rescue nil
    return if observations.blank?

    changed_obs = ''
    observations.collect do |obs|
      ["value_coded","value_datetime","value_modifier","value_numeric","value_text"].each do |value|
        case value
          when "value_coded"
            next if obs.value_coded.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_datetime"
            next if obs.value_datetime.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_numeric"
            next if obs.value_numeric.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_text"
            next if obs.value_text.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_modifier"
            next if obs.value_modifier.blank?
            changed_obs += "#{obs.to_s}</br>"
        end
      end
    end

    changed_obs.gsub("00:00:00 +0200","")[0..-6]
  end

  def visits_by_day
    @quarter    = params[:quarter]

    date_range          = Report.generate_cohort_date_range(@quarter)
    @start_date         = date_range.first
    @end_date           = date_range.last
    visits              = get_visits_by_day(@start_date.beginning_of_day, @end_date.end_of_day)
    @patients           = visiting_patients_by_day(visits)
    @visits_by_day      = visits_by_week(visits)
    @visits_by_week_day = visits_by_week_day(visits)

    render :layout => false
  end

  def visits_by_week(visits)

    visits_by_week = visits.inject({}) do |week, visit|

      day       = visit.encounter_datetime.strftime("%a")
      beginning = visit.encounter_datetime.beginning_of_week.to_date

      # add a new week
      week[beginning] = {day => []} if week[beginning].nil?

      #add a new visit to the week
      (week[beginning][day].nil?) ? week[beginning][day] = [visit] : week[beginning][day].push(visit)

      week
    end

    return visits_by_week
  end

  def visits_by_week_day(visits)
    week_day_visits = {}
    visits          = visits_by_week(visits)
    weeks           = visits.keys.sort
    week_days       = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    week_days.each_with_index do |day, index|
      weeks.map do  |week|
        visits_number = 0
        visit_date    = week.to_date.strftime("%d-%b-%Y")
        js_date       = week.to_time.to_i * 1000
        this_day      = visits[week][day]


        unless this_day.nil?
          visits_number = this_day.count
          visit_date    = this_day.first.encounter_datetime.to_date.strftime("%d-%b-%Y")
          js_date       = this_day.first.encounter_datetime.to_time.to_i * 1000
        else
        this_day      = (week.to_date + index.days)
        visit_date    = this_day.strftime("%d-%b-%Y")
        js_date       = this_day.to_time.to_i * 1000
        end

        (week_day_visits[day].nil?) ? week_day_visits[day] = [[js_date, visits_number, visit_date]] : week_day_visits[day].push([js_date, visits_number, visit_date])
      end
    end
    week_day_visits
  end

  def visiting_patients_by_day(visits)

    patients = visits.inject({}) do |patient, visit|

      visit_date = visit.encounter_datetime.strftime("%d-%b-%Y")

	  patient_bean = PatientService.get_patient(visit.patient.person)
	  
      # get a patient of a given visit
      new_patient   = { :patient_id   => (visit.patient.patient_id || ""),
                        :arv_number   => (patient_bean.arv_number || ""),
                        :name         => (patient_bean.name || ""),
                        :national_id  => (patient_bean.national_id || ""),
                        :gender       => (patient_bean.sex || ""),
                        :age          => (patient_bean.age || ""),
                        :birthdate    => (patient_bean.birth_date || ""),
                        :phone_number => (PatientService.phone_numbers(visit.patient) || ""),
                        :start_date   => (visit.patient.encounters.last.encounter_datetime.strftime("%d-%b-%Y") || "")
      }

      #add a patient to the day
      (patient[visit_date].nil?) ? patient[visit_date] = [new_patient] : patient[visit_date].push(new_patient)

      patient
    end

    patients
  end

  def get_visits_by_day(start_date,end_date)
    required_encounters = ["ART ADHERENCE", "ART_FOLLOWUP",   "ART_INITIAL",
                           "ART VISIT",     "HIV RECEPTION",  "HIV STAGING",
                           "PART_FOLLOWUP", "PART_INITIAL",   "VITALS"]

    required_encounters_ids = required_encounters.inject([]) do |encounters_ids, encounter_type|
      encounters_ids << EncounterType.find_by_name(encounter_type).id rescue nil
      encounters_ids
    end

    required_encounters_ids.sort!

    Encounter.find(:all,
      :joins      => ["INNER JOIN obs     ON obs.encounter_id    = encounter.encounter_id",
                      "INNER JOIN patient ON patient.patient_id  = encounter.patient_id"],
      :conditions => ["obs.voided = 0 AND encounter_type IN (?) AND encounter_datetime >=? AND encounter_datetime <=?",required_encounters_ids,start_date,end_date],
      :group      => "encounter.patient_id,DATE(encounter_datetime)",
      :order      => "encounter.encounter_datetime ASC")
  end

  def prescriptions_without_dispensations
      include_url_params_for_back_button

      date_range  = Report.generate_cohort_date_range(params[:quarter])
      start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
      end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
      @report     = report_prescriptions_without_dispensations_data(start_date , end_date)

      render :layout => 'report'
  end
  
  def  dispensations_without_prescriptions
       include_url_params_for_back_button

      date_range  = Report.generate_cohort_date_range(params[:quarter])
      start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
      end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
      @report     = report_dispensations_without_prescriptions_data(start_date , end_date)

       render :layout => 'report'
  end
  
  def  patients_with_multiple_start_reasons
       include_url_params_for_back_button

      date_range  = Report.generate_cohort_date_range(params[:quarter])
      start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
      end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
      @report     = report_patients_with_multiple_start_reasons(start_date , end_date)

      render :layout => 'report'
  end
  
  def out_of_range_arv_number

      include_url_params_for_back_button

      date_range        = Report.generate_cohort_date_range(params[:quarter])
      start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
      end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
      arv_number_range  = [params[:arv_start_number].to_i, params[:arv_end_number].to_i]

      @report = report_out_of_range_arv_numbers(arv_number_range, start_date, end_date)

      render :layout => 'report'
  end
  
  def data_consistency_check
      include_url_params_for_back_button
      date_range  = Report.generate_cohort_date_range(params[:quarter])
      start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
      end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")

      @dead_patients_with_visits       = report_dead_with_visits(start_date, end_date)
      @males_allegedly_pregnant        = report_males_allegedly_pregnant(start_date, end_date)
      @move_from_second_line_to_first =  report_patients_who_moved_from_second_to_first_line_drugs(start_date, end_date)
      @patients_with_wrong_start_dates = report_with_drug_start_dates_less_than_program_enrollment_dates(start_date, end_date)
      session[:data_consistency_check] = { :dead_patients_with_visits => @dead_patients_with_visits,
                                           :males_allegedly_pregnant  => @males_allegedly_pregnant,
                                           :patients_with_wrong_start_dates => @patients_with_wrong_start_dates,
                                           :move_from_second_line_to_first =>  @move_from_second_line_to_first
                                         }
      @checks = [['Dead patients with Visits', @dead_patients_with_visits.length],
                 ['Male patients with a pregnant observation', @males_allegedly_pregnant.length],
                 ['Patients who moved from 2nd to 1st line drugs', @move_from_second_line_to_first.length],
                 ['patients with start dates > first receive drug dates', @patients_with_wrong_start_dates.length]]
      render :layout => 'report'
  end
  
  def list
    @report = []
    include_url_params_for_back_button

    case params[:check_type]
       when 'Dead patients with Visits' then
            @report  =  session[:data_consistency_check][:dead_patients_with_visits]
       when 'Patients who moved from 2nd to 1st line drugs'then
             @report =  session[:data_consistency_check][:move_from_second_line_to_first]
       when 'Male patients with a pregnant observation' then
             @report =  session[:data_consistency_check][:males_allegedly_pregnant]
       when 'patients with start dates > first receive drug dates' then
             @report =  session[:data_consistency_check][:patients_with_wrong_start_dates]
       else

    end

    render :layout => 'report'
  end

  def include_url_params_for_back_button
       @report_quarter = params[:quarter]
       @report_type = params[:report_type]
  end
  
  def cohort
    @quarter = params[:quarter]
    start_date,end_date = Report.generate_cohort_date_range(@quarter)
    cohort = Cohort.new(start_date,end_date)
    @cohort = cohort.report
    @survival_analysis = SurvivalAnalysis.report(cohort)
    render :layout => 'cohort'
  end

  def cohort_menu
  end

  def adherence
    adherences = get_adherence(params[:quarter])
    @quarter = params[:quarter]
    type = "patients_with_adherence_greater_than_hundred"
    @report_type = "Adherence Histogram for all patients"
    @adherence_summary = "&nbsp;&nbsp;<button onclick='adhSummary();'>Summary</button>" unless adherences.blank?
    @adherence_summary+="<input class='test_name' type=\"button\" onmousedown=\"document.location='/cohort_tool/reports?report=#{@quarter}&report_type=#{type}';\" value=\"Over 100% Adherence\"/>"  unless adherences.blank?
    @adherence_summary_hash = Hash.new(0)
    adherences.each{|adherence,value|
      adh_value = value.to_i
      current_adh = adherence.to_i
      if current_adh <= 94
        @adherence_summary_hash["0 - 94"]+= adh_value
      elsif current_adh >= 95 and current_adh <= 100
        @adherence_summary_hash["95 - 100"]+= adh_value
      else current_adh > 100
        @adherence_summary_hash["> 100"]+= adh_value
      end
    }
    @adherence_summary_hash['missing'] = CohortTool.missing_adherence(@quarter).length rescue 0
    @adherence_summary_hash.values.each{|n|@adherence_summary_hash["total"]+=n}

    data = ""
    adherences.each{|x,y|data+="#{x}:#{y}:"}
    @id = data[0..-2] || ''

    @results = @id
    @results = @results.split(':').enum_slice(2).map
    @results = @results.each {|result| result[0] = result[0]}.sort_by{|result| result[0]}
    @results.each{|result| @graph_max = result[1].to_f if result[1].to_f > (@graph_max || 0)}
    @graph_max ||= 0
    render :layout => false
  end

  def patients_with_adherence_greater_than_hundred

      min_range = params[:min_range]
      max_range = params[:max_range]
      missing_adherence = false
      missing_adherence = true if params[:show_missing_adherence] == "yes"
      session[:list_of_patients] = nil

      @patients = adherence_over_hundred(params[:quarter],min_range,max_range,missing_adherence)

      @quarter = params[:quarter] + ": (#{@patients.length})" rescue  params[:quarter]
      if missing_adherence
        @report_type = "Patient(s) with missing adherence"
      elsif max_range.blank? and min_range.blank?
        @report_type = "Patient(s) with adherence greater than 100%"
      else
        @report_type = "Patient(s) with adherence starting from  #{min_range}% to #{max_range}%"
      end
      render :layout => 'report'
      return
  end

  def report_patients_with_multiple_start_reasons(start_date , end_date)

    art_eligibility_id = ConceptName.find_by_name('REASON FOR ART ELIGIBILITY').concept_id    
    patients = Observation.find_by_sql(
                ["SELECT person_id, concept_id, date_created, obs_datetime, value_coded_name_id
                 FROM obs
                 WHERE (SELECT COUNT(*)
                        FROM obs observation
                        WHERE   observation.concept_id = ?
                                AND observation.person_id = obs.person_id) > 1                                
                                AND date_created >= ? AND date_created <= ?
                                AND obs.concept_id = ?
                                AND obs.voided = 0", art_eligibility_id, start_date, end_date, art_eligibility_id])

    patients_data = []

    patients.each do |reason|
      patient = Patient.find(reason[:person_id])
      patient_bean = PatientService.get_patient(patient.person)
      patients_data << {'person_id' => patient.id,
                        'arv_number' => patient_bean.arv_number,
                        'national_id' => patient_bean.national_id,
                        'date_created' => reason[:date_created].strftime("%Y-%m-%d %H:%M:%S"),
                        'start_reason' => ConceptName.find(reason[:value_coded_name_id]).name
                       }
    end
   patients_data
  end

  def voided_observations(encounter)
    voided_obs = Observation.find_by_sql("SELECT * FROM obs WHERE obs.encounter_id = #{encounter.encounter_id} AND obs.voided = 1")
    (!voided_obs.empty?) ? voided_obs : nil
  end

  def voided_orders(new_encounter)
    voided_orders = Order.find_by_sql("SELECT * FROM orders WHERE orders.encounter_id = #{new_encounter.encounter_id} AND orders.voided = 1")
    (!voided_orders.empty?) ? voided_orders : nil
  end

  def report_out_of_range_arv_numbers(arv_number_range, start_date , end_date)
    arv_number_id             = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id
    arv_start_number          = arv_number_range.first
    arv_end_number            = arv_number_range.last

    out_of_range_arv_numbers  = PatientIdentifier.find_by_sql(["SELECT patient_id, identifier, date_created FROM patient_identifier
                                   WHERE identifier_type = ? AND REPLACE(identifier, 'MPC-ARV-', '') >= ?
                                   AND REPLACE(identifier, 'MPC-ARV-', '') <= ?
                                   AND voided = 0
                                   AND (NOT EXISTS(SELECT * FROM patient_identifier
                                   WHERE identifier_type = ? AND date_created >= ? AND date_created <= ?))",
                                   arv_number_id,  arv_start_number,  arv_end_number, arv_number_id, start_date, end_date])

    out_of_range_arv_numbers_data = []
    out_of_range_arv_numbers.each do |arv_num_data|
      patient     = Person.find(arv_num_data[:patient_id].to_i)
      patient_bean = PatientService.get_patient(patient.person)

      out_of_range_arv_numbers_data <<{'person_id' => patient.id,
                                       'arv_number' => patient_bean.arv_number,
                                       'name' => patient_bean.name,
                                       'national_id' => patient_bean.national_id,
                                       'gender' => patient_bean.sex,
                                       'age' => patient_bean.age,
                                       'birthdate' => patient_bean.birth_date,
                                       'date_created' => arv_num_data[:date_created].strftime("%Y-%m-%d %H:%M:%S")
                                       }
    end
    out_of_range_arv_numbers_data
  end
  
  def report_dispensations_without_prescriptions_data(start_date , end_date)
    pills_dispensed_id      = ConceptName.find_by_name('PILLS DISPENSED').concept_id

    missed_prescriptions_data = Observation.find(:all, :select =>  "person_id, value_drug, date_created",
                                              :conditions =>["order_id IS NULL
                                                AND date_created >= ? AND date_created <= ? AND
                                                    concept_id = ? AND voided = 0" ,start_date , end_date, pills_dispensed_id])
    dispensations_without_prescriptions = []

    missed_prescriptions_data.each do |dispensation|
        patient = Patient.find(dispensation[:person_id])
        patient_bean = PatientService.get_patient(patient.person)
        drug_name    = Drug.find(dispensation[:value_drug]).name

        dispensations_without_prescriptions << { 'person_id' => patient.id,
                                              'arv_number' => patient_bean.arv_number,
                                              'national_id' => patient_bean.national_id,
                                              'date_created' => dispensation[:date_created].strftime("%Y-%m-%d %H:%M:%S"),
                                              'drug_name' => drug_name
                                             }
    end

    dispensations_without_prescriptions
  end
  
  def report_prescriptions_without_dispensations_data(start_date , end_date)
    pills_dispensed_id      = ConceptName.find_by_name('PILLS DISPENSED').concept_id

    missed_dispensations_data = Observation.find_by_sql(["SELECT order_id, patient_id, date_created from orders 
              WHERE NOT EXISTS (SELECT * FROM obs
               WHERE orders.order_id = obs.order_id AND obs.concept_id = ?)
                AND date_created >= ? AND date_created <= ? AND orders.voided = 0", pills_dispensed_id, start_date , end_date ])

    prescriptions_without_dispensations = []

    missed_dispensations_data.each do |prescription|
        patient      = Patient.find(prescription[:patient_id])
        drug_id      = DrugOrder.find(prescription[:order_id]).drug_inventory_id
        drug_name    = Drug.find(drug_id).name

        prescriptions_without_dispensations << {'person_id' => patient.id,
                                                'arv_number' => PatientService.get_patient_identifier(patient, 'ARV Number'),
                                                'national_id' => PatientService.get_national_id(patient),
                                                'date_created' => prescription[:date_created].strftime("%Y-%m-%d %H:%M:%S"),
                                                'drug_name' => drug_name
                                                }
    end
    prescriptions_without_dispensations
  end

  def report_dead_with_visits(start_date, end_date)
    patient_died_concept    = ConceptName.find_by_name('PATIENT DIED').concept_id

    all_dead_patients_with_visits = "SELECT * 
    FROM (SELECT observation.person_id AS patient_id, DATE(p.death_date) AS date_of_death, DATE(observation.date_created) AS date_started
          FROM person p right join obs observation ON p.person_id = observation.person_id
          WHERE p.dead = 1 AND DATE(p.death_date) < DATE(observation.date_created) AND observation.voided = 0
          ORDER BY observation.date_created ASC) AS dead_patients_visits
    WHERE DATE(date_of_death) >= DATE('#{start_date}') AND DATE(date_of_death) <= DATE('#{end_date}')
    GROUP BY patient_id"
    patients = Patient.find_by_sql([all_dead_patients_with_visits])
    
    patients_data  = []
    patients.each do |patient_data_row|
      person = Person.find(patient_data_row[:patient_id].to_i)
      patient_bean = PatientService.get_patient(person)
      patients_data <<{ 'person_id' => person.id,
                        'arv_number' => patient_bean.arv_number,
                        'name' => patient_bean.name,
                        'national_id' => patient_bean.national_id,
                        'gender' => patient_bean.sex,
                        'age' => patient_bean.age,
                        'birthdate' => patient_bean.birth_date,
                        'phone' => PatientService.phone_numbers(person), 
                        'date_created' => patient_data_row[:date_started]
                       }
    end
    patients_data
  end
  
  def report_males_allegedly_pregnant(start_date, end_date)
    pregnant_patient_concept_id = ConceptName.find_by_name('IS PATIENT PREGNANT?').concept_id
    patients = PatientIdentifier.find_by_sql(["
                                   SELECT person.person_id,obs.obs_datetime
                                       FROM obs INNER JOIN person ON obs.person_id = person.person_id
                                           WHERE person.gender = 'M' AND
                                           obs.concept_id = ? AND obs.obs_datetime >= ? AND obs.obs_datetime <= ? AND obs.voided = 0",
        pregnant_patient_concept_id, '2008-12-23 00:00:00', end_date])

        patients_data  = []
        patients.each do |patient_data_row|
          person = Person.find(patient_data_row[:person_id].to_i)
		  patient_bean = PatientService.get_patient(person)
          patients_data <<{ 'person_id' => person.id,
                            'arv_number' => patient_bean.arv_number,
                            'name' => patient_bean.name,
                            'national_id' => patient_bean.national_id,
                            'gender' => patient_bean.sex,
                            'age' => patient_bean.age,
                            'birthdate' => patient_bean.birth_date,
                            'phone' => PatientService.phone_numbers(person),
                            'date_created' => patient_data_row[:obs_datetime]
                           }
        end
        patients_data
  end
  
  def report_patients_who_moved_from_second_to_first_line_drugs(start_date, end_date)
  
    first_line_regimen = "('D4T+3TC+NVP', 'd4T 3TC + d4T 3TC NVP')"
    second_line_regimen = "('AZT+3TC+NVP', 'D4T+3TC+EFV', 'AZT+3TC+EFV', 'TDF+3TC+EFV', 'TDF+3TC+NVP', 'TDF/3TC+LPV/r', 'AZT+3TC+LPV/R', 'ABC/3TC+LPV/r')"
    
    patients_who_moved_from_nd_to_st_line_drugs = "SELECT * FROM (
        SELECT patient_on_second_line_drugs.* , DATE(patient_on_first_line_drugs.date_created) AS date_started FROM (
        SELECT person_id, date_created
        FROM obs
        WHERE value_drug IN (
        SELECT drug_id 
        FROM drug 
        WHERE concept_id IN (SELECT concept_id FROM concept_name 
        WHERE name IN #{second_line_regimen}))
        ) AS patient_on_second_line_drugs inner join

        (SELECT person_id, date_created
        FROM obs
        WHERE value_drug IN (
        SELECT drug_id 
        FROM drug 
        WHERE concept_id IN (SELECT concept_id FROM concept_name 
        WHERE name IN #{first_line_regimen}))
        ) AS patient_on_first_line_drugs
        ON patient_on_first_line_drugs.person_id = patient_on_second_line_drugs.person_id
        WHERE DATE(patient_on_first_line_drugs.date_created) > DATE(patient_on_second_line_drugs.date_created) AND
              DATE(patient_on_first_line_drugs.date_created) >= DATE('#{start_date}') AND DATE(patient_on_first_line_drugs.date_created) <= DATE('#{end_date}')
        ORDER BY patient_on_first_line_drugs.date_created ASC) AS patients
        GROUP BY person_id"

    patients = Patient.find_by_sql([patients_who_moved_from_nd_to_st_line_drugs])
    
    patients_data  = []
    patients.each do |patient_data_row|
      person = Person.find(patient_data_row[:person_id].to_i)
      patient_bean = PatientService.get_patient(person)
      patients_data <<{ 'person_id' => person.id,
                        'arv_number' => patient_bean.arv_number,
                        'name' => patient_bean.name,
                        'national_id' => patient_bean.national_id,
                        'gender' => patient_bean.sex,
                        'age' => patient_bean.age,
                        'birthdate' => patient_bean.birth_date,
                        'phone' => PatientService.phone_numbers(person),
                        'date_created' => patient_data_row[:date_started]
                       }
    end
    patients_data
  end
  
  def report_with_drug_start_dates_less_than_program_enrollment_dates(start_date, end_date)

    arv_drugs_concepts      = MedicationService.arv_drugs.inject([]) {|result, drug| result << drug.concept_id}
    on_arv_concept_id       = ConceptName.find_by_name('ON ANTIRETROVIRALS').concept_id
    hvi_program_id          = Program.find_by_name('HIV PROGRAM').program_id
    national_identifier_id  = PatientIdentifierType.find_by_name('National id').patient_identifier_type_id
    arv_number_id           = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id

    patients_on_antiretrovirals_sql = "
         (SELECT p.patient_id, s.date_created as Date_Started_ARV
          FROM patient_program p INNER JOIN patient_state s
          ON  p.patient_program_id = s.patient_program_id
          WHERE s.state IN (SELECT program_workflow_state_id
                            FROM program_workflow_state g
                            WHERE g.concept_id = #{on_arv_concept_id})
                            AND p.program_id = #{hvi_program_id}
         ) patients_on_antiretrovirals"

    antiretrovirals_obs_sql = "
         (SELECT * FROM obs
          WHERE  value_drug IN (SELECT drug_id FROM drug
          WHERE concept_id IN ( #{arv_drugs_concepts.join(', ')} ) )
         ) antiretrovirals_obs"

    drug_start_dates_less_than_program_enrollment_dates_sql= "
      SELECT * FROM (
                  SELECT patients_on_antiretrovirals.patient_id, DATE(patients_on_antiretrovirals.date_started_ARV) AS date_started_ARV,
                         antiretrovirals_obs.obs_datetime, antiretrovirals_obs.value_drug
                  FROM #{patients_on_antiretrovirals_sql}, #{antiretrovirals_obs_sql}
                  WHERE patients_on_antiretrovirals.Date_Started_ARV > antiretrovirals_obs.obs_datetime
                        AND patients_on_antiretrovirals.patient_id = antiretrovirals_obs.person_id
                        AND patients_on_antiretrovirals.Date_Started_ARV >='#{start_date}' AND patients_on_antiretrovirals.Date_Started_ARV <= '#{end_date}'
                  ORDER BY patients_on_antiretrovirals.date_started_ARV ASC) AS patient_select
      GROUP BY patient_id"


    patients       = Patient.find_by_sql(drug_start_dates_less_than_program_enrollment_dates_sql)
    patients_data  = []
    patients.each do |patient_data_row|
      person = Person.find(patient_data_row[:patient_id])
	  patient_bean = PatientService.get_patient(person)
      patients_data <<{ 'person_id' => person.id,
                        'arv_number' => patient_bean.arv_number,
                        'name' => patient_bean.name,
                        'national_id' => patient_bean.national_id,
                        'gender' => patient_bean.sex,
                        'age' => patient_bean.age,
                        'birthdate' => patient_bean.birth_date,
                        'phone' => PatientService.phone_numbers(person), 
                        'date_created' => patient_data_row[:date_started_ARV]
                       }
    end
    patients_data
  end
  
  def get_adherence(quarter="Q1 2009")
  date = Report.generate_cohort_date_range(quarter)

  start_date  = date.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
  end_date    = date.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
  adherences  = Hash.new(0)
  adherence_concept_id = ConceptName.find_by_name("WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER").concept_id

 adherence_sql_statement= " SELECT worse_adherence_dif, pat_ad.person_id as patient_id, pat_ad.value_numeric AS adherence_rate_worse
                            FROM (SELECT ABS(100 - Abs(value_numeric)) as worse_adherence_dif, obs_id, person_id, concept_id, encounter_id, order_id, obs_datetime, location_id, value_numeric
                                  FROM obs q
                                  WHERE concept_id = #{adherence_concept_id} AND order_id IS NOT NULL
                                  ORDER BY q.obs_datetime DESC, worse_adherence_dif DESC, person_id ASC)pat_ad
                            WHERE pat_ad.obs_datetime >= '#{start_date}' AND pat_ad.obs_datetime<= '#{end_date}'
                            GROUP BY patient_id "

  adherence_rates = Observation.find_by_sql(adherence_sql_statement)

  adherence_rates.each{|adherence|

    rate = adherence.adherence_rate_worse.to_i

    if rate >= 91 and rate <= 94
      cal_adherence = 94
    elsif  rate >= 95 and rate <= 100
      cal_adherence = 100
    else
      cal_adherence = rate + (5- rate%5)%5
    end
    adherences[cal_adherence]+=1
  }
  adherences
  end

  def adherence_over_hundred(quarter="Q1 2009",min_range = nil,max_range=nil,missing_adherence=false)
    date_range                 = Report.generate_cohort_date_range(quarter)
    start_date                 = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
    end_date                   = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
    adherence_range_filter     = " (adherence_rate_worse >= #{min_range} AND adherence_rate_worse <= #{max_range}) "
    adherence_concept_id       = ConceptName.find_by_name("WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER").concept_id
    brought_drug_concept_id    = ConceptName.find_by_name("AMOUNT OF DRUG BROUGHT TO CLINIC").concept_id

    patients = {}

    if (min_range.blank? or max_range.blank?) and !missing_adherence
        adherence_range_filter = " (adherence_rate_worse > 100) "
    elsif missing_adherence

       adherence_range_filter = " (adherence_rate_worse IS NULL) "

    end

    patients_with_adherences =  " (SELECT   oders.start_date, obs_inner_order.obs_datetime, obs_inner_order.adherence_rate AS adherence_rate,
                                        obs_inner_order.id, obs_inner_order.patient_id, obs_inner_order.drug_inventory_id AS drug_id,
                                        ROUND(DATEDIFF(obs_inner_order.obs_datetime, oders.start_date)* obs_inner_order.equivalent_daily_dose, 0) AS expected_remaining,
                                        obs_inner_order.quantity AS quantity, obs_inner_order.encounter_id, obs_inner_order.order_id
                               FROM (SELECT latest_adherence.obs_datetime, latest_adherence.adherence_rate, latest_adherence.id, latest_adherence.patient_id, latest_adherence.order_id, drugOrder.drug_inventory_id, drugOrder.equivalent_daily_dose, drugOrder.quantity, latest_adherence.encounter_id
                                    FROM (SELECT all_adherences.obs_datetime, all_adherences.value_numeric AS adherence_rate, all_adherences.obs_id as id, all_adherences.person_id as patient_id,all_adherences.order_id, all_adherences.encounter_id
                                          FROM (SELECT obs_id, person_id, concept_id, encounter_id, order_id, obs_datetime, location_id, value_numeric
                                                FROM obs Observations
                                                WHERE concept_id = #{adherence_concept_id}
                                                ORDER BY person_id ASC , Observations.obs_datetime DESC )all_adherences
                                          WHERE all_adherences.obs_datetime >= '#{start_date}' AND all_adherences.obs_datetime<= '#{end_date}'
                                          GROUP BY order_id, patient_id) latest_adherence
                                    INNER JOIN
                                          drug_order drugOrder
                                    On    drugOrder.order_id = latest_adherence.order_id) obs_inner_order
                               INNER JOIN
                                    orders oders
                               On     oders.order_id = obs_inner_order.order_id) patients_with_adherence  "

      worse_adherence_per_patient =" (SELECT worse_adherence_dif, pat_ad.person_id as patient_id, pat_ad.value_numeric AS adherence_rate_worse
                                FROM (SELECT ABS(100 - Abs(value_numeric)) as worse_adherence_dif, obs_id, person_id, concept_id, encounter_id, order_id, obs_datetime, location_id, value_numeric
                                      FROM obs q
                                      WHERE concept_id = #{adherence_concept_id} AND order_id IS NOT NULL
                                      ORDER BY q.obs_datetime DESC, worse_adherence_dif DESC, person_id ASC)pat_ad
                                WHERE pat_ad.obs_datetime >= '#{start_date}' AND pat_ad.obs_datetime<= '#{end_date}'
                                GROUP BY patient_id ) worse_adherence_per_patient   "

     patient_adherences_sql =  " SELECT *
                                 FROM   #{patients_with_adherences} INNER JOIN #{worse_adherence_per_patient}
                                 ON patients_with_adherence.patient_id = worse_adherence_per_patient.patient_id
                                 WHERE  #{adherence_range_filter} "

      rates = Observation.find_by_sql(patient_adherences_sql)

      patients_rates = []
      rates.each{|rate|
        patients_rates << rate
      }
      adherence_rates = patients_rates

    arv_number_id = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id
    adherence_rates.each{|rate|

      patient    = Patient.find(rate.patient_id)
      person     = patient.person
      patient_bean = PatientService.get_patient(person)
      drug       = Drug.find(rate.drug_id)
      pill_count = Observation.find(:first, :conditions => "order_id = #{rate.order_id} AND encounter_id = #{rate.encounter_id} AND concept_id = #{brought_drug_concept_id} ").value_numeric rescue ""
      if !patients[patient.patient_id] then

          patients[patient.patient_id]={"id" =>patient.id,
                                        "arv_number" => patient_bean.arv_number,
                                        "name" => patient_bean.name,
                                        "national_id" => patient_bean.national_id,
                                        "visit_date" =>rate.obs_datetime,
                                        "gender" =>patient_bean.sex,
                                        "age" => PatientService.patient_age_at_initiation(patient, rate.start_date.to_date),
                                        "birthdate" => patient_bean.birth_date,
                                        "pill_count" => pill_count.to_i.to_s,
                                        "adherence" => rate. adherence_rate_worse,
                                        "start_date" => rate.start_date.to_date,
                                        "expected_count" =>rate.expected_remaining,
                                        "drug" => drug.name}
   elsif  patients[patient.patient_id] then

          patients[patient.patient_id]["age"].to_i < PatientService.patient_age_at_initiation(patient, rate.start_date.to_date).to_i ? patients[patient.patient_id]["age"] = patient.age_at_initiation(rate.start_date.to_date).to_s : ""

          patients[patient.patient_id]["drug"] = patients[patient.patient_id]["drug"].to_s + "<br>#{drug.name}"

          patients[patient.patient_id]["pill_count"] << "<br>#{pill_count.to_i.to_s}"

          patients[patient.patient_id]["expected_count"] << "<br>#{rate.expected_remaining.to_i.to_s}"

          patients[patient.patient_id]["start_date"].to_date > rate.start_date.to_date ?
          patients[patient.patient_id]["start_date"] = rate.start_date.to_date : ""

    end
    }

    patients.sort { |a,b| a[1]['adherence'].to_i <=> b[1]['adherence'].to_i }
  end
  
 def discharge_by_ward

    @report_name = params[:report_name]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]
    @age_groups = params[:age_groups].map{|g|g.upcase}
    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date
    @total_registered = []
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')

    report = Reports::ReportIpd.new()
    @patients_discharged_by_wards = report.discharges_by_ward(@start_date, @end_date)
    
    @admission_discharge_summary = []
    
    admissions = {}
    Observation.find(:all, 
                            :select => "count(*) total_patients, IFNULL(value_text,(SELECT name from concept_name where concept_id = value_coded LIMIT 1)) as ward", 
                            :conditions => ["DATE(obs_datetime) >= ? AND DATE(obs_datetime) <= ? AND concept_id= ?", 
                             @start_date, @end_date, Concept.find_by_name("ADMIT TO WARD")],  
                            :group => "ward"
        ).map{|o| admissions[o.ward] = o.total_patients}

    @patients_discharged_by_wards.each do |ward|
      if admissions.include?(ward.ward)
        @admission_discharge_summary << [ward.ward, ward.total_patients_discharged, admissions[ward.ward]]
      end
    end
    render :layout => "report"  
  end
  
  def dead_patients_statistic_per_ward

    @report_name = params[:report_name]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]
    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date
    @total_registered = []
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')

    report = Reports::ReportIpd.new()
    @dead_patients_per_ward = report.dead_patients_statistic_per_ward(@start_date, @end_date)
    
    @dead_patients_statistic_summary = []
    @total_patients_died = 0
    
    @dead_patients_per_ward.each do |ward|
      if ward.total_dead.to_i == 1
        @total_patients_died += 1
      end
      @dead_patients_statistic_summary << [ ward.ward,
                                            ward.total_dead,
                                            ward.total_dated_in_24hrs,
                                            ward.dead_btn_24_and_72hrs,
                                            ward.dead_btn_3_and_7dys,
                                            ward.dead_after_7dys,
                                            ward.dead_patients_hiv_positive]

    end

    render :layout => "report"
  end

  def dead_patients_statistic_per_ward_patient_list

    @report_name = params[:field] 
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    start_date = params[:start_date].to_date
    end_date = params[:end_date].to_date
    @start_date = start_date
    @end_date = end_date
    @total_registered = []
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')

    report = Reports::ReportIpd.new()
    @dead_patients_per_ward = report.dead_patients_statistic_per_ward_patient_list(@start_date, @end_date)
    @patients = []
    @total_patients_died = []

    @dead_patients_per_ward.each do |patient|
      if patient.ward == params[:ward]
        person = Person.find(patient.patient_id)
        if params[:field] == "total_patients_dead"
          @patients << person
          @report_name = "#{patient.ward} - Total patients died"
        elsif params[:field] == "total_died_in_24_hrs"
          @patients << person
          @report_name = "#{patient.ward} - Total patients died within 24 hrs"
        elsif params[:field] == "dead_btn_24_and_72hrs"
          @patients << person
          @report_name = "#{patient.ward} - Total patients died between 24 and 72 hrs"
        elsif params[:field] == "dead_btn_3_and_7dys"
          @patients << person
          @report_name = "#{patient.ward} - Total patients died between 3 and 7 days"
        elsif params[:field] == "dead_after_7dys"
          @patients << person
          @report_name = "#{patient.ward} - Total patients died after 7 days"
        else params[:field] == "dead_patients_with_hiv_positive"
          @patients << person
          @report_name = "#{patient.ward} - Total HIV patients died"
        end
      end
    end

    @total_patients_died = @patients
    @total_patients = []
    @total_female_registered = 0
    @total_male_registered = 0
    
    @patients.each do | person |
      name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
      @total_patients << [ name, person.birthdate, person.gender,
                                    person.date_created.to_date,
                                    person.addresses.first.city_village,
                                    person.addresses.first.county_district]
      if person.gender == 'F'
        @total_female_registered += 1
      else
        @total_male_registered += 1
      end
    end

    render :layout => "report"
  end

  def ipd_menu
	  @shifts =[
			["Day","day"],
			["Night","night"],
			["24 Hours","24_hour"],
			["Specific","specific"]
		]

		@report_name = params[:report_name]
  end
  
  def admissions

    @report_name = params[:report_name]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]
    @age_groups = params[:age_groups].map{|g|g.upcase}
    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date
    @total_registered = []
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')
    
    report = Reports::ReportIpd.new()
    @patients_in_wards = report.admissions_by_ward(@start_date, @end_date)

    @admission_summary = []
    
    @patients = Observation.find(:all, 
                            :select => "count(*) total_patients, IFNULL(value_text,(SELECT name from concept_name where concept_id = value_coded LIMIT 1)) as ward", 
                            :conditions => ["DATE(obs_datetime) >= ? AND DATE(obs_datetime) <= ? AND concept_id= ?", 
                             @start_date, @end_date, Concept.find_by_name("ADMIT TO WARD").concept_id],  
                            :group => "ward"
        )

    @patients.each do |ward|
      @admission_summary << [ward.ward, ward.total_patients]
    end
    
    render :layout => "report"
  end
  
  def admissions_patient_list

    @report_name = params[:report_name]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]
    @age_groups = params[:age_groups].map{|g|g.upcase}
    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date
    @total_registered = []
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')

    report = Reports::ReportIpd.new()
    @patients_in_wards = report.patients_in_wards(@start_date, @end_date)
    admitted_patients = []

    @patients_in_wards.each do  |patient|
      person = Person.find(patient.person_id)

      if (@age_groups.include?("< 6 MONTHS"))
        if (PatientService.age_in_months(person).to_i < 6 )
            admitted_patients << person
        end
      end

      if (@age_groups.include?("6 MONTHS TO < 1 YR"))
        if (PatientService.age_in_months(person).to_i >= 6 && PatientService.age(person).to_i < 1)
            admitted_patients << person
        end
      end

      if (@age_groups.include?("1 TO < 5"))
        if (PatientService.age(person).to_i >= 1 && PatientService.age(person).to_i < 5)
            admitted_patients << person
        end
      end

      if (@age_groups.include?("5 TO 14"))
        if (PatientService.age(person).to_i >= 5 && PatientService.age(person).to_i < 14)
            admitted_patients << person
        end
      end

      if (@age_groups.include?("> 14 TO < 20"))
        if (PatientService.age(person).to_i >= 14 && PatientService.age(person).to_i < 20)
            admitted_patients << person
        end
      end

      if (@age_groups.include?("20 TO < 30"))
        if (PatientService.age(person).to_i >= 20 && PatientService.age(person).to_i < 30)
            admitted_patients << person
        end
      end

      if (@age_groups.include?("30 TO < 40"))
        if (PatientService.age(person).to_i >= 30 && PatientService.age(person).to_i < 40)
            admitted_patients << person
        end
      end

      if (@age_groups.include?("40 TO < 50"))
        if (PatientService.age(person).to_i >= 40 && PatientService.age(person).to_i < 50)
            admitted_patients << person
        end
      end

      if (@age_groups.include?("ALL"))
            admitted_patients << person
      end
    end
    
    @total_patients_in_wards = @patients_in_wards
    @total_admitted_patients = []
    @total_female_registered = 0
    @total_male_registered = 0

    @patients_in_wards.each do | patient |
      person = Person.find(patient.person_id)
      name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
      @total_admitted_patients << [ name, person.birthdate, person.gender,
                                    person.date_created.to_date,
                                    patient.ward,
                                    patient.admission_date.to_date]
      if person.gender == 'F'
        @total_female_registered += 1
      else
        @total_male_registered += 1
      end
    end

    render :layout => "report"
  end

  def re_admissions

    @report_name = params[:report_name]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name = Location.current_health_center.name
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]
    @age_groups = params[:age_groups].map{|g|g.upcase}
    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date
    @total_registered = []
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')

    report = Reports::ReportIpd.new()
    @patient_readmissions = report.re_admissions(@start_date, @end_date)
    @total_patients_admitted = report.admissions_by_ward(@start_date,@end_date)

     @day = []
     @readmission_in_three_months = []
     @readmission_in_six_months = []
     @patient_readmissions.each do |patient|
        if patient.days.to_i < 91
          @readmission_in_three_months << patient
        elsif patient.days.to_i < 181
          @readmission_in_six_months << patient
        end
     end
     
    @readmission_in_three_months_female = []
    @readmission_in_three_months_male = []
    @readmission_in_three_months.each do | patient |
      person = Person.find(patient.patient_id)
                                     
      if person.gender == 'F'
        @readmission_in_three_months_female << person
      else
        @readmission_in_three_months_male << person
      end
    end
    

    @readmission_in_six_months_female = []
    @readmission_in_six_months_male = []
    @readmission_in_six_months.each do | patient |
      person = Person.find(patient.patient_id)
                                     
      if person.gender == 'F'
        @readmission_in_six_months_female << person
      else
        @readmission_in_six_months_male << person
      end
    end
    
    @total_re_admitted_female = []
    @total_re_admitted_male = []
    @patient_readmissions.each do | patient |
      person = Person.find(patient.patient_id)
                                     
      if person.gender == 'F'
        @total_re_admitted_female << person
      else
        @total_re_admitted_male << person
      end
    end
  
    @admitted_patients = Observation.find(:all, 
                            :select => "person_id AS patient_id, IFNULL(value_text,(SELECT name from concept_name where concept_id = value_coded LIMIT 1)) as ward", 
                            :conditions => ["DATE(obs_datetime) >= ? AND DATE(obs_datetime) <= ? AND concept_id= ? AND voided = 0", 
                             @start_date, @end_date, Concept.find_by_name("ADMIT TO WARD")])

    @total_admitted_female = []
    @total_admitted_male = []

    @admitted_patients.each do | patient |
      person = Person.find(patient.patient_id)
                                     
      if person.gender == 'F'
        @total_admitted_female << person
      else
        @total_admitted_male << person
      end
    end
  
    render :layout => "report"
  end

  def re_admissions_patient_details

    @report_name = params[:field]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    start_date = params[:start_date].to_date
    end_date = params[:end_date].to_date
    @start_date = start_date
    @end_date = end_date
    @total_registered = []
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')

    report = Reports::ReportIpd.new()
    
    @patient_readmissions = report.re_admissions(@start_date, @end_date)
    @readmission_in_three_months = []
     @readmission_in_six_months = []
     @patient_readmissions.each do |patient|
        if patient.days.to_i < 91
          @readmission_in_three_months << patient
        elsif patient.days.to_i < 181
          @readmission_in_six_months << patient
        end
     end


    if params[:field] == 'total_admitted'
      @patients = Observation.find(:all, 
                            :select => "person_id AS patient_id, IFNULL(value_text,(SELECT name from concept_name where concept_id = value_coded LIMIT 1)) as ward", 
                            :conditions => ["DATE(obs_datetime) >= ? AND DATE(obs_datetime) <= ? AND concept_id= ? AND voided = 0", 
                             @start_date, @end_date, Concept.find_by_name("ADMIT TO WARD")])

    elsif params[:field] == 'total_re_admitted'
        @patients = @patient_readmissions
    elsif params[:field] == 'total_re_admitted_in_3mths'
        @patients = @readmission_in_three_months
    elsif params[:field] == 'total_re_admitted_in_6mths'
        @patients = @readmission_in_six_months
    end

    @people = []
    @diagnosis_report_patients = @people
    @total_patients = []
    @total_female_registered = 0
    @total_male_registered = 0

    @patients.each do | patient |

      person = Person.find(patient.patient_id)
      name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
      @total_patients << [ name, person.birthdate, person.gender,
                                    person.date_created.to_date,
                                    person.addresses.first.city_village,
                                    person.addresses.first.county_district]
      if person.gender == 'F'
        @total_female_registered += 1
      else
        @total_male_registered += 1
      end
    end
    render :layout => "report"
  end

  def specific_hiv_related_data
    @report_name = params[:report_name]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]
    @age_groups = params[:age_groups].map{|g|g.upcase}
    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date
    @total_registered = []
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')
    
    report = Reports::ReportIpd.new()
    @specific_hiv_related_data = report.specific_hiv_related_data(@start_date, @end_date)

    @specific_hiv_related_data_summary = []

    @specific_hiv_related_data.each do |ward|

      @specific_hiv_related_data_summary << [ward.ward, ward.total_admitted]
    end
    
    render :layout => "report"
  end

  def specific_hiv_related_data_patient_details

    @report_name = params[:ward] + " (HIV Reactive patients)"
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name = Location.current_health_center.name
    start_date = params[:start_date]
    end_date = params[:end_date]
    @age_groups = params[:age_groups].map{|g|g.upcase}
    @start_date = start_date.to_date
    @end_date = end_date.to_date
    @total_registered = []
    @people = []
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')

    report = Reports::ReportIpd.new()
    @specific_hiv_related_data = report.specific_hiv_related_data_patient_details(@start_date, @end_date)
    
    @specific_hiv_related_data.each do |obs|
          if obs.ward == params[:ward]
            person = Person.find(obs.person_id)

            if (PatientService.age_in_months(person).to_i < 6 )
                @people << person
             end

            if (@age_groups.include?("6 MONTHS TO < 1 YR"))
              if (PatientService.age_in_months(person).to_i >= 6 && PatientService.age(person).to_i < 1)
               @people << person
              end
            end

            if (@age_groups.include?("1 TO < 5"))
              if (PatientService.age(person).to_i >= 1 && PatientService.age(person).to_i < 5)
               @people << person
              end
            end

            if (@age_groups.include?("5 TO 14"))
              if (PatientService.age(person).to_i >= 5 && PatientService.age(person).to_i < 14)
               @people << person
              end
            end

            if (@age_groups.include?("> 14 TO < 20"))
              if (PatientService.age(person).to_i >= 14 && PatientService.age(person).to_i < 20)
               @people << person
              end
            end

            if (@age_groups.include?("20 TO < 30"))
              if (PatientService.age(person).to_i >= 20 && PatientService.age(person).to_i < 30)
               @people << person
              end
            end

            if (@age_groups.include?("30 TO < 40"))
              if (PatientService.age(person).to_i >= 30 && PatientService.age(person).to_i < 40)
               @people << person
              end
            end

            if (@age_groups.include?("40 TO < 50"))
              if (PatientService.age(person).to_i >= 40 && PatientService.age(person).to_i < 50)
               @people << person
              end
            end

            if (@age_groups.include?("ALL"))
               @people << person
            end
         end
        end

    @diagnosis_report_patients = @patients
    @total_patients = []
    @total_female_registered = 0
    @total_male_registered = 0

    @people.each do | person |
      name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
      @total_patients << [ name, person.birthdate, person.gender,
                                    person.date_created.to_date,
                                    person.addresses.first.city_village,
                                    person.addresses.first.county_district]
      if person.gender == 'F'
        @total_female_registered += 1
      else
        @total_male_registered += 1
      end
    end

    render :layout => "report"
  end

  def total_registration_report

    @report_name = params[:report_name]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]
    @age_groups = params[:age_groups].map{|g|g.upcase}
    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date
    @total_registered = []
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')
    @admit_patient_encounter_id = EncounterType.find_by_name("ADMIT PATIENT").encounter_type_id

    report = Reports::ReportIpd.new()
    @patients = Observation.find(:all, 
                            :select => "person_id, IFNULL(value_text,(SELECT name from concept_name where concept_id = value_coded LIMIT 1)) as ward, DATE(obs_datetime) as admission_date",
                            :joins => "LEFT JOIN encounter ON encounter.encounter_id = obs.encounter_id",
                            :conditions => ["DATE(obs.obs_datetime) >= ? AND DATE(obs.obs_datetime) <= ?
                                             AND obs.concept_id= ? AND obs.voided = 0 AND encounter.voided = 0
                                             AND encounter.encounter_type = ?", @start_date, @end_date, 
                                             Concept.find_by_name("ADMIT TO WARD").concept_id, @admit_patient_encounter_id],
                            :group => "person_id, ward, DATE(obs_datetime)" )

        peoples = []

        @patients.each do  |patient|
          person = Person.find(patient.person_id)
          if (@age_groups.include?("< 6 MONTHS"))
            if (PatientService.age_in_months(person).to_i < 6 )
                peoples << person
            end
          end

          if (@age_groups.include?("6 MONTHS TO < 1 YR"))
            if (PatientService.age_in_months(person).to_i >= 6 && PatientService.age(person).to_i < 1)
                peoples << person
            end
          end

          if (@age_groups.include?("1 TO < 5"))
            if (PatientService.age(person).to_i >= 1 && PatientService.age(person).to_i < 5)
                peoples << person
            end
          end

          if (@age_groups.include?("5 TO 14"))
            if (PatientService.age(person).to_i >= 5 && PatientService.age(person).to_i < 14)
                peoples << person
            end
          end

          if (@age_groups.include?("> 14 TO < 20"))
            if (PatientService.age(person).to_i >= 14 && PatientService.age(person).to_i < 20)
                peoples << person
            end
          end

          if (@age_groups.include?("20 TO < 30"))
            if (PatientService.age(person).to_i >= 20 && PatientService.age(person).to_i < 30)
                peoples << person
            end
          end

          if (@age_groups.include?("30 TO < 40"))
            if (PatientService.age(person).to_i >= 30 && PatientService.age(person).to_i < 40)
                peoples << person
            end
          end

          if (@age_groups.include?("40 TO < 50"))
            if (PatientService.age(person).to_i >= 40 && PatientService.age(person).to_i < 50)
                peoples << person
            end
          end

          if (@age_groups.include?("ALL"))
                peoples << person
          end

        end
      @total_registered = peoples
      @registered = []
      @total_female_registered = []
      @total_male_registered = []

      @patients.each do | patient |
        person = Person.find(patient.person_id)
        name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
        @registered << [name, person.birthdate, person.gender,
        patient.admission_date,
        patient.ward,
        person.addresses.first.city_village,]
        
        if(PatientService.sex(person) == 'Female')
          @total_female_registered << patient
        else
          @total_male_registered << patient
        end

      end
#raise @registered.to_yaml
    render :layout => "report"
  end

	def total_registration

    @report_name = params[:report_name]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]
    @age_groups = params[:age_groups].map{|g|g.upcase}
    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date
    @total_registered = []
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')

    report = Reports::ReportIpd.new()
    @total_patients_registered = report.total_registered(@start_date,@end_date)
  
    people = Person.find(:all,:include =>{:patient=>{:encounters=>{:type=>{}}}},
        :conditions => ["patient.patient_id IS NOT NULL AND encounter_type.name IN (?)
        AND person.date_created >= TIMESTAMP(?)
        AND person.date_created  <= TIMESTAMP(?)", ["TREATMENT","OUTPATIENT DIAGNOSIS"],
        @start_date.strftime('%Y-%m-%d 00:00:00'),
        @end_date.strftime('%Y-%m-%d 23:59:59')])

        peoples = []
        people.each do  |person|

          if (@age_groups.include?("< 6 MONTHS"))
            if (PatientService.age_in_months(person).to_i < 6 )
                peoples << person
            end
          end

          if (@age_groups.include?("6 MONTHS TO < 1 YR"))
            if (PatientService.age_in_months(person).to_i >= 6 && PatientService.age(person).to_i < 1)
                peoples << person
            end
          end

          if (@age_groups.include?("1 TO < 5"))
            if (PatientService.age(person).to_i >= 1 && PatientService.age(person).to_i < 5)
                peoples << person
            end
          end

          if (@age_groups.include?("5 TO 14"))
            if (PatientService.age(person).to_i >= 5 && PatientService.age(person).to_i < 14)
                peoples << person
            end
          end

          if (@age_groups.include?("> 14 TO < 20"))
            if (PatientService.age(person).to_i >= 14 && PatientService.age(person).to_i < 20)
                peoples << person
            end
          end

          if (@age_groups.include?("20 TO < 30"))
            if (PatientService.age(person).to_i >= 20 && PatientService.age(person).to_i < 30)
                peoples << person
            end
          end

          if (@age_groups.include?("30 TO < 40"))
            if (PatientService.age(person).to_i >= 30 && PatientService.age(person).to_i < 40)
                peoples << person
            end
          end

          if (@age_groups.include?("40 TO < 50"))
            if (PatientService.age(person).to_i >= 40 && PatientService.age(person).to_i < 50)
                peoples << person
            end
          end

          if (@age_groups.include?("ALL"))
                peoples << person
          end

        end
      @total_registered = peoples
      @registered = []
      @total_female_registered = 0
      @total_male_registered = 0

      peoples.each do | person_id |
        person = Person.find(person_id)
        name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
        @registered << [name, person.birthdate, person.gender,
        person.date_created.to_date,
        person.addresses.first.city_village,
        person.addresses.first.county_district]
        
        if(PatientService.sex(person) == 'Female')
          @total_female_registered += 1
        else
          @total_male_registered += 1
        end

      end

    render :layout => "report"
  end

  def diagnosis_by_address

    @report_name = params[:report_name]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    age_groups = params[:age_groups]
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]
    @age_groups = age_groups.map{|g|g.upcase}
    @required = ["TREATMENT","OUTPATIENT DIAGNOSIS"]
    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date
    @diagnosis_by_address = {}
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')
      
    concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)",
      ["Additional diagnosis","Diagnosis", "primary diagnosis",
      "secondary diagnosis"]]).map(&:concept_id)
    admission_diagnosis_encounter_id = EncounterType.find_by_name("ADMISSION DIAGNOSIS").encounter_type_id
    
    observations = Observation.find(:all, :include=>{:person=>{}},
                    :joins      => "LEFT JOIN encounter ON encounter.encounter_id = obs.encounter_id",
                    :conditions => ["obs.obs_datetime >= TIMESTAMP(?)
                    AND obs.obs_datetime  <= TIMESTAMP(?) AND obs.concept_id IN (?) AND obs.voided = 0 AND encounter.voided = 0 AND encounter.encounter_type = ?",
                    @start_date.strftime('%Y-%m-%d 00:00:00'), @end_date.strftime('%Y-%m-%d 23:59:59'),
                    concept_ids, admission_diagnosis_encounter_id],
                    :group => "person_id, concept_id,DATE(obs_datetime)")

      observations.each do | obs|
        next if obs.answer_concept.nil?
          if (@age_groups.include?("< 6 MONTHS"))
            if (PatientService.age_in_months(obs.person).to_i < 6 )
              diagnosis_name = obs.answer_concept.fullname rescue ''
              @diagnosis_by_address[diagnosis_name] = {} if @diagnosis_by_address[diagnosis_name].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] = 0 if @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] += 1
            end
          end

          if (@age_groups.include?("6 MONTHS TO < 1 YR"))
            if (PatientService.age_in_months(obs.person).to_i >= 6 && PatientService.age(obs.person).to_i < 1)
              diagnosis_name = obs.answer_concept.fullname rescue ''
              @diagnosis_by_address[diagnosis_name] = {} if @diagnosis_by_address[diagnosis_name].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] = 0 if @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] += 1
            end
          end

          if (@age_groups.include?("1 TO < 5"))
            if (PatientService.age(obs.person).to_i >= 1 && PatientService.age(obs.person).to_i < 5)
              diagnosis_name = obs.answer_concept.fullname rescue ''
              @diagnosis_by_address[diagnosis_name] = {} if @diagnosis_by_address[diagnosis_name].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] = 0 if @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] += 1
            end
          end

          if (@age_groups.include?("5 TO 14"))
            if (PatientService.age(obs.person).to_i >= 5 && PatientService.age(obs.person).to_i < 14)
              diagnosis_name = obs.answer_concept.fullname rescue ''
              @diagnosis_by_address[diagnosis_name] = {} if @diagnosis_by_address[diagnosis_name].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] = 0 if @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] += 1
            end
          end

          if (@age_groups.include?("> 14 TO < 20"))
            if (PatientService.age(obs.person).to_i >= 14 && PatientService.age(obs.person).to_i < 20)
              diagnosis_name = obs.answer_concept.fullname rescue ''
              @diagnosis_by_address[diagnosis_name] = {} if @diagnosis_by_address[diagnosis_name].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] = 0 if @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] += 1
            end
          end

          if (@age_groups.include?("20 TO < 30"))
            if (PatientService.age(obs.person).to_i >= 20 && PatientService.age(obs.person).to_i < 30)
              diagnosis_name = obs.answer_concept.fullname rescue ''
              @diagnosis_by_address[diagnosis_name] = {} if @diagnosis_by_address[diagnosis_name].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] = 0 if @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] += 1
            end
          end

          if (@age_groups.include?("30 TO < 40"))
            if (PatientService.age(obs.person).to_i >= 30 && PatientService.age(obs.person).to_i < 40)
              diagnosis_name = obs.answer_concept.fullname rescue ''
              @diagnosis_by_address[diagnosis_name] = {} if @diagnosis_by_address[diagnosis_name].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] = 0 if @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] += 1
            end
          end

          if (@age_groups.include?("40 TO < 50"))
            if (PatientService.age(obs.person).to_i >= 40 && PatientService.age(obs.person).to_i < 50)
              diagnosis_name = obs.answer_concept.fullname rescue ''
              @diagnosis_by_address[diagnosis_name] = {} if @diagnosis_by_address[diagnosis_name].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] = 0 if @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district].nil?
              @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] += 1
            end
          end

          if (@age_groups.include?("ALL"))
            diagnosis_name = obs.answer_concept.fullname rescue ''
            @diagnosis_by_address[diagnosis_name] = {} if @diagnosis_by_address[diagnosis_name].nil?
            @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] = 0 if @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district].nil?
            @diagnosis_by_address[diagnosis_name][obs.person.addresses.first.county_district] += 1
          end
      end
    @diagn_address = []
    @diagnosis_by_address.each { |diagn|
      diagnosis = diagn[0]
      address_total = diagn[1]
      address_total.each { |address,total|
        @diagn_address << [diagnosis,address,total]
      }
    }
    render :layout => "report"
  end

  def diagnosis_by_address_patient_details

    @report_name = params[:field] + " (#{ params[:address]})"
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    start_date = params[:start_date]
    end_date = params[:end_date]
    @age_groups = params[:age_groups].map{|g|g.upcase}
    @start_date = start_date.to_date
    @end_date = end_date.to_date
    @total_registered = []
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')

    concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)",
      ["Additional diagnosis","Diagnosis", "primary diagnosis",
      "secondary diagnosis"]]).map(&:concept_id)

    admission_diagnosis_encounter_id = EncounterType.find_by_name("ADMISSION DIAGNOSIS").encounter_type_id
    
    observations = Observation.find(:all, :include=>{:person=>{}},
                    :joins      => "LEFT JOIN encounter ON encounter.encounter_id = obs.encounter_id",
                    :conditions => ["obs.obs_datetime >= TIMESTAMP(?)
                    AND obs.obs_datetime  <= TIMESTAMP(?) AND obs.concept_id IN (?) AND obs.voided = 0 AND encounter.voided = 0 AND encounter.encounter_type = ?",
                    @start_date.strftime('%Y-%m-%d 00:00:00'), @end_date.strftime('%Y-%m-%d 23:59:59'),
                    concept_ids, admission_diagnosis_encounter_id],
                    :group => "person_id, concept_id, DATE(obs_datetime)")

    @people = []
    observations.each do | obs|
        next if obs.answer_concept.nil?
          diagnosis_name = obs.answer_concept.fullname rescue '' 
          if diagnosis_name == params[:field]
            if obs.person.addresses.first.county_district == params[:address]
              if (PatientService.age_in_months(obs.person).to_i < 6 )
                  @people << obs.person
               end

              if (@age_groups.include?("6 MONTHS TO < 1 YR"))
                if (PatientService.age_in_months(obs.person).to_i >= 6 && PatientService.age(obs.person).to_i < 1)
                 @people << obs.person
                end
              end

              if (@age_groups.include?("1 TO < 5"))
                if (PatientService.age(obs.person).to_i >= 1 && PatientService.age(obs.person).to_i < 5)
                 @people << obs.person
                end
              end

              if (@age_groups.include?("5 TO 14"))
                if (PatientService.age(obs.person).to_i >= 5 && PatientService.age(obs.person).to_i < 14)
                 @people << obs.person
                end
              end

              if (@age_groups.include?("> 14 TO < 20"))
                if (PatientService.age(obs.person).to_i >= 14 && PatientService.age(obs.person).to_i < 20)
                 @people << obs.person
                end
              end

              if (@age_groups.include?("20 TO < 30"))
                if (PatientService.age(obs.person).to_i >= 20 && PatientService.age(obs.person).to_i < 30)
                 @people << obs.person
                end
              end

              if (@age_groups.include?("30 TO < 40"))
                if (PatientService.age(obs.person).to_i >= 30 && PatientService.age(obs.person).to_i < 40)
                 @people << obs.person
                end
              end

              if (@age_groups.include?("40 TO < 50"))
                if (PatientService.age(obs.person).to_i >= 40 && PatientService.age(obs.person).to_i < 50)
                 @people << obs.person
                end
              end

              if (@age_groups.include?("ALL"))
                @people << obs.person
              end
            end
          end
          
    end
      @total_registered = @people
      @registered = []
      @total_female_registered = 0
      @total_male_registered = 0

      @people.each do | person |
        person = Person.find(person.person_id)
        name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
        @registered << [name, person.birthdate, person.gender,
        person.date_created.to_date,
        person.addresses.first.city_village,
        person.addresses.first.county_district]
        
        if(PatientService.sex(person) == 'Female')
          @total_female_registered += 1
        else
          @total_male_registered += 1
        end

      end
    render :layout => "report"
  end

	def total_registration_graph

    @report_name = params[:report_name]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]

    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date
    @total_registered = 0
    @total_female_registered = 0
    @total_male_registered = 0
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')

    people = Person.find(:all,:include =>{:patient=>{:encounters=>{:type=>{}}}},
        :conditions => ["patient.patient_id IS NOT NULL AND encounter_type.name IN (?)
        AND person.date_created >= TIMESTAMP(?)
        AND person.date_created  <= TIMESTAMP(?)", ["TREATMENT","OUTPATIENT DIAGNOSIS"],
        @start_date.strftime('%Y-%m-%d 00:00:00'),
        @end_date.strftime('%Y-%m-%d 23:59:59')])
        @peoples = Hash.new(0)
        people.each do  |person|


            if (PatientService.age_in_months(person).to_i < 6 )
                if(PatientService.sex(person) == 'Male')
                	@peoples['Under6M'] +=1
                else
	                @peoples['Under6F'] +=1
                end

            end

            if (PatientService.age_in_months(person).to_i >= 6 && PatientService.age(person).to_i < 1)
                if(PatientService.sex(person) == 'Male')
                	@peoples['Under12MM'] +=1
                else
	                @peoples['Under12MF'] +=1
                end

            end

            if (PatientService.age(person).to_i >= 1 && PatientService.age(person).to_i < 5)
                if(PatientService.sex(person) == 'Male')
                	@peoples['Under5YM'] +=1
                else
	                @peoples['Under5YF'] +=1
                end

            end

            if (PatientService.age(person).to_i >= 5 && PatientService.age(person).to_i < 14)
                if(PatientService.sex(person) == 'Male')
                	@peoples['Under14YM'] +=1
                else
	                @peoples['Under14YF'] +=1
                end

            end

            if (PatientService.age(person).to_i >= 14 && PatientService.age(person).to_i < 20)
                if(PatientService.sex(person) == 'Male')
                	@peoples['Under20YM'] +=1
                else
	                @peoples['Under20YF'] +=1
                end

            end

            if (PatientService.age(person).to_i >= 20 && PatientService.age(person).to_i < 30)
                if(PatientService.sex(person) == 'Male')
                	@peoples['Under30YM'] +=1
                else
	                @peoples['Under30YF'] +=1
                end

            end

            if (PatientService.age(person).to_i >= 30 && PatientService.age(person).to_i < 40)
                if(PatientService.sex(person) == 'Male')
                	@peoples['Under40YM'] +=1
                else
	                @peoples['Under40YF'] +=1
                end

            end

            if (PatientService.age(person).to_i >= 40 && PatientService.age(person).to_i < 50)
                if(PatientService.sex(person) == 'Male')
                	@peoples['Under50YM'] +=1
                else
	                @peoples['Under50YF'] +=1
                end

            end
						
						if (PatientService.age(person).to_i >= 50)
                if(PatientService.sex(person) == 'Male')
                	@peoples['Over50YM'] +=1
                else
	                @peoples['Over50YF'] +=1
                end

            end
            
            if(PatientService.sex(person) == 'Female')
              @total_female_registered += 1
            else
              @total_male_registered += 1
            end
    		@total_registered +=1
    		
        end    

    render :layout => "report"
  end

  def diagnosis_report 
    @report_name = params[:report_name]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    age_groups = params[:age_groups]
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]

    @age_groups = age_groups.map{|g|g.upcase}
    @required = ["TREATMENT","OUTPATIENT DIAGNOSIS"]
    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date
    @disaggregated_diagnosis = {}
    @diagnosis_by_address = {}
    @diagnosis_name = {}
    @diagnosis_report = Hash.new(0)
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')
    concept_ids = ConceptName.find(:all,
    :conditions => ["name IN (?)",["Additional diagnosis","Diagnosis",
    "primary diagnosis","secondary diagnosis"]]).map(&:concept_id)

    admission_diagnosis_encounter_id = EncounterType.find_by_name("ADMISSION DIAGNOSIS").encounter_type_id
    
    observations = Observation.find(:all, :include=>{:person=>{}},
                    :joins      => "LEFT JOIN encounter ON encounter.encounter_id = obs.encounter_id",
                    :conditions => ["obs.obs_datetime >= TIMESTAMP(?)
                    AND obs.obs_datetime  <= TIMESTAMP(?) AND obs.concept_id IN (?) AND obs.voided = 0 AND encounter.voided = 0 AND encounter.encounter_type = ?",
                    @start_date.strftime('%Y-%m-%d 00:00:00'), @end_date.strftime('%Y-%m-%d 23:59:59'),
                    concept_ids, admission_diagnosis_encounter_id],
                    :group => "person_id, concept_id,DATE(obs_datetime)")

        observations.each do |obs|
          next if obs.answer_concept.blank?
          diagnosis_name = obs.answer_concept.fullname rescue ''
           if (PatientService.age_in_months(obs.person).to_i < 6 )
              @diagnosis_report[diagnosis_name]+=1
           end

          if (@age_groups.include?("6 MONTHS TO < 1 YR"))
            if (PatientService.age_in_months(obs.person).to_i >= 6 && PatientService.age(obs.person).to_i < 1)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("1 TO < 5"))
            if (PatientService.age(obs.person).to_i >= 1 && PatientService.age(obs.person).to_i < 5)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("5 TO 14"))
            if (PatientService.age(obs.person).to_i >= 5 && PatientService.age(obs.person).to_i < 14)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("> 14 TO < 20"))
            if (PatientService.age(obs.person).to_i >= 14 && PatientService.age(obs.person).to_i < 20)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("20 TO < 30"))
            if (PatientService.age(obs.person).to_i >= 20 && PatientService.age(obs.person).to_i < 30)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("30 TO < 40"))
            if (PatientService.age(obs.person).to_i >= 30 && PatientService.age(obs.person).to_i < 40)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("40 TO < 50"))
            if (PatientService.age(obs.person).to_i >= 40 && PatientService.age(obs.person).to_i < 50)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("ALL"))
            @diagnosis_report[diagnosis_name]+=1
          end
        end

      @diagnosis_report_paginated = []
      @diagnosis_report.each { | diag, value |
        @diagnosis_report_paginated << [diag, value]
      }
    render :layout => "report"
  end

  def discharge_diagnosis_report 
    @report_name = params[:report_name]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    age_groups = params[:age_groups]
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]

    @age_groups = age_groups.map{|g|g.upcase}
    @required = ["TREATMENT","OUTPATIENT DIAGNOSIS"]
    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date
    @disaggregated_diagnosis = {}
    @diagnosis_by_address = {}
    @diagnosis_name = {}
    @diagnosis_report_patients = []
    @diagnosis_report = Hash.new(0)
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')
    concept_ids = ConceptName.find(:all,
    :conditions => ["name IN (?)",["Additional diagnosis","Diagnosis",
    "primary diagnosis","secondary diagnosis"]]).map(&:concept_id)

    discharge_diagnosis_encounter_id = EncounterType.find_by_name("DISCHARGE DIAGNOSIS").encounter_type_id
     
    observation = Observation.find(:all, :include=>{:person=>{}},
                    :joins      => "INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id",
                    :conditions => ["obs.obs_datetime >= TIMESTAMP(?)
                    AND obs.obs_datetime  <= TIMESTAMP(?) AND obs.concept_id IN (?)
                    AND encounter.encounter_type = ?",
                    @start_date.strftime('%Y-%m-%d 00:00:00'), @end_date.strftime('%Y-%m-%d 23:59:59'),
                    concept_ids,discharge_diagnosis_encounter_id])

        observation.each do |obs|
          next if obs.answer_concept.blank?
          diagnosis_name = obs.answer_concept.fullname rescue ''
           if (PatientService.age_in_months(obs.person).to_i < 6 )
              @diagnosis_report[diagnosis_name]+=1
           end

          if (@age_groups.include?("6 MONTHS TO < 1 YR"))
            if (PatientService.age_in_months(obs.person).to_i >= 6 && PatientService.age(obs.person).to_i < 1)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("1 TO < 5"))
            if (PatientService.age(obs.person).to_i >= 1 && PatientService.age(obs.person).to_i < 5)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("5 TO 14"))
            if (PatientService.age(obs.person).to_i >= 5 && PatientService.age(obs.person).to_i < 14)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("> 14 TO < 20"))
            if (PatientService.age(obs.person).to_i >= 14 && PatientService.age(obs.person).to_i < 20)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("20 TO < 30"))
            if (PatientService.age(obs.person).to_i >= 20 && PatientService.age(obs.person).to_i < 30)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("30 TO < 40"))
            if (PatientService.age(obs.person).to_i >= 30 && PatientService.age(obs.person).to_i < 40)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("40 TO < 50"))
            if (PatientService.age(obs.person).to_i >= 40 && PatientService.age(obs.person).to_i < 50)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("ALL"))
            @diagnosis_report[diagnosis_name] += 1

            @diagnosis_report_patients << [obs.person_id, diagnosis_name]#, @diagnosis_report]

          end
        end

      @diagnosis_report_paginated = []
      @diagnosis_report.each { | diag, value |
        @diagnosis_report_paginated << [diag, value]
      }
    render :layout => "report"
  end

  def discharge_diagnosis_patient_details
    @report_name = params[:field]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    age_groups = params[:age_groups]
    start_date = params[:start_date]
    end_date = params[:end_date]

    @age_groups = age_groups.map{|g|g.upcase}
    @required = ["TREATMENT","OUTPATIENT DIAGNOSIS"]
    @start_date = start_date.to_date
    @end_date = end_date.to_date
    @disaggregated_diagnosis = {}
    @diagnosis_by_address = {}
    @diagnosis_name = {}
    @diagnosis_report_patients = []
    @diagnosis_report = Hash.new(0)
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')
    
    concept_ids = ConceptName.find(:all,
    :conditions => ["name IN (?)",["Additional diagnosis","Diagnosis",
    "primary diagnosis","secondary diagnosis"]]).map(&:concept_id)

    discharge_diagnosis_encounter_id = EncounterType.find_by_name("DISCHARGE DIAGNOSIS").encounter_type_id
    
    if params[:category] == 'discharge_diagnosis'
      observations = Observation.find(:all, :include=>{:person=>{}},
                      :joins      => "INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id",
                      :conditions => ["obs.obs_datetime >= TIMESTAMP(?)
                      AND obs.obs_datetime  <= TIMESTAMP(?) AND obs.concept_id IN (?)
                      AND encounter.encounter_type = ?",
                      @start_date.strftime('%Y-%m-%d 00:00:00'), @end_date.strftime('%Y-%m-%d 23:59:59'),
                      concept_ids,discharge_diagnosis_encounter_id])

   else params[:category] == 'all_diagnosis'
      admission_diagnosis_encounter_id = EncounterType.find_by_name("ADMISSION DIAGNOSIS").encounter_type_id
    
      observations = Observation.find(:all, :include=>{:person=>{}},
                    :joins      => "LEFT JOIN encounter ON encounter.encounter_id = obs.encounter_id",
                    :conditions => ["obs.obs_datetime >= TIMESTAMP(?)
                    AND obs.obs_datetime  <= TIMESTAMP(?) AND obs.concept_id IN (?) AND obs.voided = 0 AND encounter.voided = 0 AND encounter.encounter_type = ?",
                    @start_date.strftime('%Y-%m-%d 00:00:00'), @end_date.strftime('%Y-%m-%d 23:59:59'),
                    concept_ids, admission_diagnosis_encounter_id],
                    :group => "person_id, concept_id,DATE(obs_datetime)")
   end
    
    @patients = []

        observations.each do |obs|
          next if obs.answer_concept.blank?
          diagnosis_name = obs.answer_concept.fullname rescue ''
          
          if diagnosis_name == params[:field]
            patient = Patient.find(obs.person_id)
            if (PatientService.age_in_months(obs.person).to_i < 6 )
                @patients << patient
             end

            if (@age_groups.include?("6 MONTHS TO < 1 YR"))
              if (PatientService.age_in_months(obs.person).to_i >= 6 && PatientService.age(obs.person).to_i < 1)
               @patients << patient
              end
            end

            if (@age_groups.include?("1 TO < 5"))
              if (PatientService.age(obs.person).to_i >= 1 && PatientService.age(obs.person).to_i < 5)
               @patients << patient
              end
            end

            if (@age_groups.include?("5 TO 14"))
              if (PatientService.age(obs.person).to_i >= 5 && PatientService.age(obs.person).to_i < 14)
               @patients << patient
              end
            end

            if (@age_groups.include?("> 14 TO < 20"))
              if (PatientService.age(obs.person).to_i >= 14 && PatientService.age(obs.person).to_i < 20)
               @patients << patient
              end
            end

            if (@age_groups.include?("20 TO < 30"))
              if (PatientService.age(obs.person).to_i >= 20 && PatientService.age(obs.person).to_i < 30)
               @patients << patient
              end
            end

            if (@age_groups.include?("30 TO < 40"))
              if (PatientService.age(obs.person).to_i >= 30 && PatientService.age(obs.person).to_i < 40)
               @patients << patient
              end
            end

            if (@age_groups.include?("40 TO < 50"))
              if (PatientService.age(obs.person).to_i >= 40 && PatientService.age(obs.person).to_i < 50)
               @patients << patient
              end
            end

            if (@age_groups.include?("ALL"))
               @patients << patient
            end
         end
        end

    @diagnosis_report_patients = @patients
    @total_patients = []
    @total_female_registered = 0
    @total_male_registered = 0

    @patients.each do | patient |

      person = Person.find(patient.patient_id)
      name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
      @total_patients << [ name, person.birthdate, person.gender,
                                    person.date_created.to_date,
                                    person.addresses.first.city_village,
                                    person.addresses.first.county_district]
      if person.gender == 'F'
        @total_female_registered += 1
      else
        @total_male_registered += 1
      end
    end

		render :layout => 'report'
  end

  def discharge_by_ward_patient_details
    @report_name = params[:ward] + " (Patients #{params[:field]})"
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    age_groups = params[:age_groups]
    start_date = params[:start_date]
    end_date = params[:end_date]

    @age_groups = age_groups.map{|g|g.upcase}
    @required = ["TREATMENT","OUTPATIENT DIAGNOSIS"]
    @start_date = start_date.to_date
    @end_date = end_date.to_date
    @disaggregated_diagnosis = {}
    @diagnosis_by_address = {}
    @diagnosis_name = {}
    @diagnosis_report_patients = []
    @diagnosis_report = Hash.new(0)
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')
    report = Reports::ReportIpd.new()

    if params[:field].upcase == "DISCHARGED"
      @patients = report.discharge_by_ward_patient_list(@start_date, @end_date)
    elsif params[:field].upcase == "ADMITTED"
      @patients = Observation.find(:all, 
                            :select => "person_id AS patient_id, IFNULL(value_text,(SELECT name from concept_name where concept_id = value_coded LIMIT 1)) as ward", 
                            :conditions => ["DATE(obs_datetime) >= ? AND DATE(obs_datetime) <= ? AND concept_id= ? AND voided = 0", 
                             @start_date, @end_date, Concept.find_by_name("ADMIT TO WARD")])
    end
    
    @admission_discharge_summary = []
        
    @people = []
    @patients.each do |obs|

      if obs.ward == params[:ward]
        person = Person.find(obs.patient_id)

        if (PatientService.age_in_months(person).to_i < 6 )
          @people << person
        end

        if (@age_groups.include?("6 MONTHS TO < 1 YR"))
          if (PatientService.age_in_months(operson).to_i >= 6 && PatientService.age(person).to_i < 1)
            @people << person
          end
        end

        if (@age_groups.include?("1 TO < 5"))
          if (PatientService.age(person).to_i >= 1 && PatientService.age(person).to_i < 5)
            @people << person
          end
        end

        if (@age_groups.include?("5 TO 14"))
          if (PatientService.age(person).to_i >= 5 && PatientService.age(person).to_i < 14)
            @people << person
          end
        end

        if (@age_groups.include?("> 14 TO < 20"))
          if (PatientService.age(person).to_i >= 14 && PatientService.age(person).to_i < 20)
            @people << person
          end
        end

        if (@age_groups.include?("20 TO < 30"))
          if (PatientService.age(person).to_i >= 20 && PatientService.age(person).to_i < 30)
            @people << person
          end
        end

        if (@age_groups.include?("30 TO < 40"))
          if (PatientService.age(person).to_i >= 30 && PatientService.age(person).to_i < 40)
            @people << person
          end
        end

        if (@age_groups.include?("40 TO < 50"))
          if (PatientService.age(person).to_i >= 40 && PatientService.age(person).to_i < 50)
            @people << person
          end
        end

        if (@age_groups.include?("ALL"))
          @people << person
        end        
        
      end
    end
    
    @diagnosis_report_patients = @patients
    @total_patients = []
    @total_female_registered = 0
    @total_male_registered = 0
    @people.each do | person |

      person = Person.find(person.person_id)
      name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
      @total_patients << [ name, person.birthdate, person.gender,
                                    person.date_created.to_date,
                                    person.addresses.first.city_village,
                                    person.addresses.first.county_district]
      if person.gender == 'F'
        @total_female_registered += 1
      else
        @total_male_registered += 1
      end
    end

		render :layout => 'report'
  end

  def diagnosis_report_graph
    @report_name = params[:report_name]
    @logo = CoreService.get_global_property_value('logo').to_s
    @current_location_name =Location.current_health_center.name
    age_groups = params[:age_groups]
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]

    @age_groups = age_groups.map{|g|g.upcase}
    @required = ["TREATMENT","OUTPATIENT DIAGNOSIS"]
    @start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    @end_date = (end_year + "-" + end_month + "-" + end_day).to_date
    @disaggregated_diagnosis = {}
    @diagnosis_by_address = {}
    @diagnosis_name = {}
    @diagnosis_report = Hash.new(0)
    @formated_start_date = @start_date.strftime('%A, %d, %b, %Y')
    @formated_end_date = @end_date.strftime('%A, %d, %b, %Y')
    concept_ids = ConceptName.find(:all,
    :conditions => ["name IN (?)",["Additional diagnosis","Diagnosis",
    "primary diagnosis","secondary diagnosis"]]).map(&:concept_id)
1974
      observation = Observation.find(:all, :include => {:person =>{}},
        :conditions => ["obs.obs_datetime >= TIMESTAMP(?) AND obs.obs_datetime
        <= TIMESTAMP(?) AND obs.concept_id IN (?)",
        @start_date.strftime('%Y-%m-%d 00:00:00'),
        @end_date.strftime('%Y-%m-%d 23:59:59'),concept_ids])

        observation.each do |obs|
          next if obs.answer_concept.blank?
          diagnosis_name = obs.answer_concept.fullname rescue ''
           if (PatientService.age_in_months(obs.person).to_i < 6 )
              @diagnosis_report[diagnosis_name]+=1
           end

          if (@age_groups.include?("6 MONTHS TO < 1 YR"))
            if (PatientService.age_in_months(obs.person).to_i >= 6 && PatientService.age(obs.person).to_i < 1)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("1 TO < 5"))
            if (PatientService.age(obs.person).to_i >= 1 && PatientService.age(obs.person).to_i < 5)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("5 TO 14"))
            if (PatientService.age(obs.person).to_i >= 5 && PatientService.age(obs.person).to_i < 14)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("> 14 TO < 20"))
            if (PatientService.age(obs.person).to_i >= 14 && PatientService.age(obs.person).to_i < 20)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("20 TO < 30"))
            if (PatientService.age(obs.person).to_i >= 20 && PatientService.age(obs.person).to_i < 30)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("30 TO < 40"))
            if (PatientService.age(obs.person).to_i >= 30 && PatientService.age(obs.person).to_i < 40)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("40 TO < 50"))
            if (PatientService.age(obs.person).to_i >= 40 && PatientService.age(obs.person).to_i < 50)
              @diagnosis_report[diagnosis_name]+=1
            end
          end

          if (@age_groups.include?("ALL"))
            @diagnosis_report[diagnosis_name]+=1
          end
        end

      @diagnosis_report_paginated = []
      @diagnosis_report.each { | diag, value |
        @diagnosis_report_paginated << [diag, value]
      }

  	@ara = Array.new
  	@ara = [[0, 3], [4, 8], [8, 5], [9, 13],[2,8],[5,12],[7,15],[1,16]]

    render :layout => 'report'
  end

  def ipd_report_index
    @reports = ['Report 1','Report 2']
  end
  
  def report1

    flash[:notice] = ""
    unless params[:start_date].to_date <= params[:end_date].to_date
      flash[:notice] = "Start Date must be less than or equal to End Date"
      @reports = ['Report 1','Report 2']
      render :index
      return
    end

    start_date = params[:start_date]
    end_date = params[:end_date]

    @start_date = params[:start_date]
    @end_date = params[:end_date]

    @total_males = 0
    @total_females = 0
    @total_age_male = 0
    @total_age_female = 0
    report = Reports::ReportIpd.new()
    @patients_registered = report.patients_registered(start_date, end_date)
    #raise report.dead_patients_statistic_per_ward(start_date, end_date).to_yaml

    @patients_registered.each do|patient|
      if patient.gender == 'M'
        @total_males += 1
        @total_age_male += patient.age.to_i
        else
        @total_females += 1
        @total_age_female += patient.age.to_i
      end
    end

    @admissions = {} # From here, there is need for editing 
    @patients_in_wards = report.patients_in_wards(start_date, end_date)

    @patients_in_wards.each do |ward|
        @admissions[ward.ward] = {} if !@admissions[ward.ward]
        if ward.gender == 'M'
             @admissions[ward.ward]["total_male"] =  ward.gender
        else
             @admissions[ward.ward]["total_female"] = ward.gender
        end
     end

     @patient_readmissions = report.re_admissions(start_date, end_date)
     @total_patient_readmissions = @patient_readmissions.length
     @readmission_in_three_months = 0
     @readmission_in_six_months = 0

     @day = []
     @patient_readmissions.each do |patient|
        if patient.days.to_i < 91
          @readmission_in_three_months = @readmission_in_three_months + 1
        elsif patient.days.to_i < 181
          @readmission_in_six_months = @readmission_in_six_months + 1
        end
     end

     @total_primary_diag_equal_to_secondary = report.total_patients_with_primary_diagnosis_equal_to_secondary(start_date, end_date)
     @top_ten_syndromic_diagnosis =  report.top_ten_syndromic_diagnosis(start_date, end_date)
     @total_top_ten_syndromic_diagnosis = 0

     @top_ten_syndromic_diagnosis.each do |diagnosis|
        @total_top_ten_syndromic_diagnosis += diagnosis.total_occurance.to_i
     end

     @patient_admission_discharge_summary = report.patient_admission_discharge_summary(start_date, end_date)

     @primary_diagnosis_and_hiv_stat = report.statistic_of_top_ten_primary_diagnosis_and_hiv_status(start_date, end_date)

     @total_top_ten_primary_diagnosis = 0
     @primary_diagnosis_and_hiv_stat.each do |diagnosis|
        @total_top_ten_primary_diagnosis += diagnosis.total.to_i
     end
     @dead_patients_statistic_per_ward = report.dead_patients_statistic_per_ward(start_date, end_date)

     @specific_hiv_related_data = report.specific_hiv_related_data(start_date, end_date)
     @total_patient_admission_per_ward = {}
     render :layout => 'reports'

  end

  def adt_report_menu

  end

  def adt_report_menu_by_ward
    @kch_wards = Ward.find(:all, :conditions => ["voided =?",0]).collect{|ward|[ward.name.squish, ward.name.squish]}
    @kch_wards = @kch_wards.sort
  end

  def shift_report_menu
    @kch_wards = Ward.find(:all, :conditions => ["voided =?",0]).collect{|ward|[ward.name.squish, ward.name.squish]}
    @kch_wards = @kch_wards.sort
    @shifts =[
			["Day","day"],
			["Night","night"],
			#["24 Hours","24_hour"],
			["Specific","specific"]
		]  
  end

end


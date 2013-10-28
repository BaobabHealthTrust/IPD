class ClinicController < GenericClinicController

	def reports_tab
		@reports = [
      #["Total Registered", "/cohort_tool/ipd_menu?report_name=total_registered_report"],
		  #["Admission Diagnosis (By address)", "/cohort_tool/ipd_menu?report_name=diagnosis_by_address"],
		  #["Admission Diagnosis", "/cohort_tool/ipd_menu?report_name=diagnosis_report"],
		  #["Admissions (By Wards)", "/cohort_tool/ipd_menu?report_name=admissions"],
      #["Re-admissions (Totals)", "/cohort_tool/ipd_menu?report_name=re_admissions"],
		  #["Discharge (By Wards)", "/cohort_tool/ipd_menu?report_name=discharge_by_ward"],
		  #["Discharge Diagnosis", "/cohort_tool/ipd_menu?report_name=discharge_diagnosis_report"],
			#["Specific HIV Related data (By Wards)", "/cohort_tool/ipd_menu?report_name=specific_hiv_related_data"],
      #["Deaths (By Wards)", "/cohort_tool/ipd_menu?report_name=dead_patients_statistic_per_ward"],
      ["General ADT report", "/cohort_tool/adt_report_menu"],
      ["ADT report By Ward", "/cohort_tool/adt_report_menu_by_ward"],
      ["Shift Report", "/cohort_tool/shift_report_menu"],
      ["Report By Team", "/cohort_tool/report_team_menu"],
      ["Daily Report", "/cohort_tool/daily_report_menu"]
      #["IPD Reports", "/cohort_tool/ipd_report_index"]
      #["Graphical Reports", "/clinic/reports_tab_graphs"]
		]
		render :layout => false
	end
  
  def reports_tab_graphs
	   session[:observation] = nil
    session[:people] = nil
    @facility = Location.current_health_center.name rescue ''

    @location = Location.find(session[:location_id]).name rescue ""

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

    @user = current_user.name rescue ""

    @roles = current_user.user_roles.collect{|r| r.role} rescue []

    @reports = [
						      ["OPD General", "/cohort_tool/opd_report_index_graph"],
	     						["Diagnosis Report", "/cohort_tool/ipd_menu?report_name=diagnosis_report_graph"],
	     						["Total Registered", "/cohort_tool/ipd_menu?report_name=total_registered_graph"],
      						["Transfer Out", "/cohort_tool/ipd_menu?report_name=referals_graph"]
      						
               ] 
 	    render :layout => false
  end

	def properties_tab
		@settings = [
		
		["Manage Roles", "/properties/set_role_privileges"],
		
		["Show Lab Results", "/properties/creation?value=show_lab_results"],
    ["Show Column prescrp. interface", "/properties/creation?value=use_column_interface"],
		["Ask admission time", "/properties/creation?value=ask_admission_time"]
		]
		render :layout => false
	end
	def administration_tab
		@reports =  [
				      ['/clinic/users_tab','User Accounts/Settings'],
				      ['/clinic/location_management_tab','Location Management'],
				    ]
		if current_user.admin?
		  @reports << ['/clinic/management_tab','Drug Management']
      #@reports << ['/clinic/add_bed_number','Add Bed Numbers']
      #@reports << ['/clinic/add_wards','Add Wards']
      #@reports << ['/clinic/list_wards','Void Wards']
      @reports << ['/clinic/manage_wards_tab','Manage Wards']
      @reports << ['/clinic/manage_teams_tab','Manage Teams']
      #@reports << ['/clinic/add_teams','Add Teams']
      @reports << ['/clinic/overstay_patients_menu','Discharge Overstay Patients']
		end
		@landing_dashboard = 'clinic_administration'
		render :layout => false
	end

  def view_wards
    @logo = CoreService.get_global_property_value('logo')
    @kch_wards = Ward.find(:all, :conditions => ["voided =?",0]).collect{|ward|[ward.id, ward.name.squish, ward.bed_number]}

    available_wards = Ward.find(:all, :conditions => ["voided =?",0]).collect{|ward|[ward.name.squish]}
    concept_id = Concept.find_by_name('ADMIT TO WARD').id
    @admission_by_ward = {}
    available_wards.each do |ward|
      obs = Observation.find(:all, :conditions => ["concept_id =? AND value_text =?", concept_id, ward])
      @admission_by_ward[ward.to_s] = {}
      @admission_by_ward[ward.to_s]['count'] = obs.map(&:person_id).uniq.count
    end

    render :layout => "menu"
  end

  def add_bed_number
    @logo = CoreService.get_global_property_value('logo')
    #@kch_wards = CoreService.get_global_property_value('kch_wards').split(',')
    @kch_wards = Ward.find(:all, :conditions => ["voided =?",0]).collect{|ward|[ward.name.squish, ward.id]}
    render :layout => "application"
  end
  
  def manage_wards_tab
    @reports =  []
		if current_user.admin?
      @reports << ['/clinic/add_bed_number','Add Bed Numbers']
      @reports << ['/clinic/add_wards','Add Wards']
      @reports << ['/clinic/list_wards','Void Wards']
      @reports << ['/clinic/view_wards','View Wards']
      @reports << ['/clinic/voided_wards_list','Undo Voiding of wards']
		end
		@landing_dashboard = 'clinic_administration'
		render :layout => false
  end

  def manage_teams_tab
    @reports =  []
		if current_user.admin?
      @reports << ['/clinic/add_teams','Add Teams']
      @reports << ['/clinic/remove_teams','Remove Teams']
		end
		@landing_dashboard = 'clinic_administration'
		render :layout => false
  end

  def remove_teams
    @kch_teams = Team.find(:all).collect{|team|team.name}
    if request.method == :post
      total_teams = Team.all.count
      if (total_teams > 1)
      team_name = params[:team_name]
      team = Team.find_by_name(team_name)
      team.delete
      redirect_to("/clinic") and return
      else
        flash[:notice] = "Can't delete the last team"
      end
    end
    render:layout => "application"
  end
  
  def create_ward_beds
    ward_id = params[:ward_id]
    total_beds = params[:bed_number].to_s rescue nil
    ward = Ward.find(ward_id)
    ward.bed_number = total_beds
    ward.save!
    redirect_to("/")
  end

  def add_wards
    render :layout => "application"
  end

  def save_wards
  wards = params[:wards]
  ward_name = params[:ward_name].to_s
  bed_number = params[:bed_number].to_s
  new_ward = Ward.new
  new_ward.name = ward_name
  new_ward.bed_number = bed_number
  new_ward.save!
=begin
  wards = wards.split(",").compact rescue nil
    unless wards.blank?
      wards.each do |ward|
        available_ward = Ward.find(:first, :conditions => ["name =?  AND voided =?", ward, 0]) rescue nil
        next unless available_ward.blank?
        new_ward = Ward.new
        new_ward.name = ward
        new_ward.save!
      end
    end
=end
  redirect_to("/clinic")
  end

  def list_wards
    @kch_wards = Ward.find(:all, :conditions => ["voided =?",0]).collect{|ward|[ward.name.squish, ward.id]}
    render :layout => "application"
  end

  def void_wards
    ward_ids = params[:wards]
    ward_ids.each do |ward_id|
      ward = Ward.find(ward_id)
      ward.voided = 1
      ward.voided_by = User.current.id
      ward.date_voided = Time.now
      ward.save!
    end
    redirect_to("/clinic")
  end

  def voided_wards_list
    @kch_voided_wards = Ward.find(:all, :conditions => ["voided =?",1]).collect{|ward|[ward.name.squish, ward.id]}
    render :layout => "application"
  end

  def undo_void_wards
    ward_ids = params[:wards]
    ward_ids.each do |ward_id|
      ward = Ward.find(ward_id)
      ward.voided = 0
      ward.voided_by = nil
      ward.date_voided = nil
      ward.save!
    end
    redirect_to("/clinic")
  end

  def add_teams
    if request.method == :post
      team = Team.new()
      team.name = params[:team_name].squish
      team.save
      redirect_to("/clinic") and return
    end
    render :layout => "application"
  end

  def select_team
    @kch_teams = Team.all.collect{|ward|[ward.name.squish, ward.name.squish]}
    if request.method == :post
      session[:team_name] = params[:team_name]
      redirect_to("/clinic") and return
    end
    render :layout => "application"
  end

  def overstay_patients_menu
    @periods = [
      ["2 months to <=4 months",">=2_to_4_months"],
      [">4 months to <=6 months",">4_to_6_months"],
      [">6 months to <=8 months",">6_to_8_months"],
      [">8 months to <=10 months",">8_to_10_months"],
      [">10 months to <= 1 year",">10_to_12_months"],
      [">1 year",">1 year"]
    ]
    render :layout => "application"
  end

  def overstay_patients
    period  = params[:period]
    program_id =  Program.find_by_name('IPD Program').program_id
    patient_programs = PatientProgram.find(:all, :conditions => ['date_enrolled < NOW() 
      AND (date_completed IS NULL OR date_completed > NOW()) AND 
      program_id = ?',program_id])
    today = Date.today
    patient_ids = []
    @patient_details = {}
    patient_programs.each do |program|
        date_enrolled = program.date_enrolled.to_date
        period_in_hospital = ((today - date_enrolled).to_f)/30
        if period.include?(">=2_to_4_months")
          if (period_in_hospital >= 2 && period_in_hospital <= 4)
            patient_ids << program.patient_id
          end

        end
        if period.include?(">4_to_6_months")
          if (period_in_hospital > 4 && period_in_hospital <= 6)
            patient_ids << program.patient_id
          end
        end
        if period.include?(">6_to_8_months")
          if (period_in_hospital > 6 && period_in_hospital <= 8)
            patient_ids << program.patient_id
          end
        end
        if period.include?(">8_to_10_months")
          if (period_in_hospital > 8 && period_in_hospital <= 10)
            patient_ids << program.patient_id
          end
        end
        if period.include?(">10_to_12_months")
          if (period_in_hospital > 10 && period_in_hospital <= 12)
            patient_ids << program.patient_id
          end
        end
        if period.include?(">1 year")
          if (period_in_hospital > 12)
            patient_ids << program.patient_id
          end
        end
      end
      patient_ids.each do |patient_id|
        patient_program = PatientProgram.find(:last, :conditions => ['date_enrolled < NOW()
          AND (date_completed IS NULL OR date_completed > NOW()) AND
          program_id = ? AND patient_id =?',program_id, patient_id])
        date_admitted = patient_program.date_enrolled.to_date
        #period_on_admission = ((today - date_admitted).to_i)/30
        period_on_admission = ((today - date_admitted).to_i).divmod(30)
        patient = Patient.find(patient_id)
        patient_bean = PatientService.get_patient(patient.person)
        @patient_details[patient_id] = {}
        @patient_details[patient_id][:national_id] = patient_bean.national_id
        @patient_details[patient_id][:fname] = patient_bean.first_name
        @patient_details[patient_id][:lname] = patient_bean.last_name
        @patient_details[patient_id][:date_admitted] = patient_program.date_enrolled.to_date
        @patient_details[patient_id][:admission_period] = period_on_admission
      end
      #raise @patient_details.to_yaml
      render :layout => "menu"
  end

  def discharge_overstay_patients
    patient_ids = params[:patient_ids].split(",")
    discharge_date = params[:discharge_date].to_date
    program_id =  Program.find_by_name('IPD Program').program_id
    concept_id = Concept.find_by_name('DISCHARGED').concept_id
    state = ProgramWorkflowState.find_by_concept_id(concept_id).id
    patient_ids.each do |patient_id|
        patient_program = PatientProgram.find(:last, :conditions => ['date_enrolled < NOW()
            AND (date_completed IS NULL OR date_completed > NOW()) AND
            program_id = ? AND patient_id =?',program_id, patient_id])

        current_active_state = patient_program.patient_states.last
        current_active_state.end_date = discharge_date
        current_active_state.save
        patient_state = patient_program.patient_states.build(
          :state => state,
          :start_date => discharge_date)
        patient_state.save
        patient_program.date_completed = discharge_date.strftime('%Y-%m-%d 00:00:01')
        patient_program.save
    end
    redirect_to("/clinic")
  end

  def select_discharge_date
    render :layout => "application"
  end
  
end
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
      ["ADT report", "/cohort_tool/adt_report_menu"]
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
      @reports << ['/clinic/manage_wards','Manage Wards']
      @reports << ['/clinic/add_wards','Add Wards']
		end
		@landing_dashboard = 'clinic_administration'
		render :layout => false
	end

  def manage_wards
    @logo = CoreService.get_global_property_value('logo')
    #@kch_wards = CoreService.get_global_property_value('kch_wards').split(',')
    @kch_wards = Ward.find(:all).collect{|ward|[ward.name, ward.id]}
    render :layout => "application"
  end

  def create_ward_beds
    ward_id = params[:ward_id]
    total_beds = params[:bed_number].to_s rescue nil
    ward = Ward.find(ward_id)
    ward.bed_number = total_beds
    ward.save!
    redirect_to :action => "manage_wards"
  end

  def add_wards
    render :layout => "application"
  end

  def save_wards
  wards = params[:wards]
  wards = wards.split(",").compact rescue nil
    unless wards.blank?
      wards.each do |ward|
        available_ward = Ward.find(:first, :conditions => ["name =? ", ward]) rescue nil
        next unless available_ward.blank?
        new_ward = Ward.new
        new_ward.name = ward
        new_ward.save!
      end
    end
  end
end

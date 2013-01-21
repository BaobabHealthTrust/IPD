class ClinicController < GenericClinicController

	def reports_tab
		@reports = [
      ["Total Registered", "/cohort_tool/ipd_menu?report_name=total_registered_report"],
		  ["Diagnosis (By address)", "/cohort_tool/ipd_menu?report_name=diagnosis_by_address"],
		  ["Diagnosis Report", "/cohort_tool/ipd_menu?report_name=diagnosis_report"],
		  ["Admissions", "/cohort_tool/ipd_menu?report_name=admissions"],
      ["Re-admissions", "/cohort_tool/ipd_menu?report_name=re_admissions"],
		  ["Discharge (By Ward)", "/cohort_tool/ipd_menu?report_name=discharge_by_ward"],
		  ["Discharge Diagnosis", "/cohort_tool/ipd_menu?report_name=discharge_diagnosis_report"],
			["Specific HIV Related data", "/cohort_tool/ipd_menu?report_name=specific_hiv_related_data"],      
      ["Deaths", "/cohort_tool/ipd_menu?report_name=dead_patients_statistic_per_ward"]
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
		end
		@landing_dashboard = 'clinic_administration'
		render :layout => false
	end
  
end

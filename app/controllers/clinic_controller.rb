class ClinicController < GenericClinicController

	def reports_tab
		@reports = [
		  ["IPD Reports", "/cohort_tool/ipd_report_index"]
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

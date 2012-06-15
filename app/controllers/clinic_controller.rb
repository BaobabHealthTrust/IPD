class ClinicController < GenericClinicController

  def reports_tab
    @reports = [
      ["IPD Reports", "/cohort_tool/ipd_report_index"]
    ]
    render :layout => false
  end
  
end

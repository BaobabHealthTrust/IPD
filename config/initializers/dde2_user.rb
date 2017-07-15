if (CoreService.get_global_property_value('create.from.dde.server').to_s == "true" rescue false)
  require 'dde2_service'
  token = DDE2Service.token rescue nil
  if token.blank?
    token = DDE2Service.authenticate_by_admin
    puts "Token  = #{token}"
    auth  = DDE2Service.add_user(token) rescue nil
    if auth.blank?
      DDE2Service.authenticate
    end
  end
end

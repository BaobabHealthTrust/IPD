=begin
	By Kenneth Kapundi
	13-Jun-2016

	DESC:
		This service acts as a wrapper for all DDE2 interactions 
		between the application and the DDE2 proxy at a site
		This include:	
			A. User creation and authentication
			B. Creating new patient to DDE
			C. Updating already existing patient to DDE2
			D. Handling duplicates in DDE2
			E. Any other DDE2 related functionality to arise
=end

require 'rest-client'

module DDE2Service

  def self.dde2_configs
    YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env]
  end

  def self.dde2_url
    dde2_configs = self.dde2_configs
    protocol = dde2_configs['secure_connection'].to_s == 'true' ? 'https' : 'http'
    "#{protocol}://#{dde2_configs['dde_server']}"
  end

  def self.dde2_url_with_auth
    dde2_configs = self.dde2_configs
    protocol = dde2_configs['secure_connection'].to_s == 'true' ? 'https' : 'http'
    "#{protocol}://#{dde2_configs['dde_username']}:#{dde2_configs['dde_password']}@#{dde2_configs['dde_server']}"
  end

  def self.authenticate
    dde2_configs = self.dde2_configs
    url = "#{self.dde2_url}/v1/authenticate"

    res = JSON.parse(RestClient.post(url,
            {'username' => dde2_configs['dde_username'],
              'password' => dde2_configs['dde_password']}.to_json, :content_type => 'application/json'))
    token = nil
    if (res.present? && res['status'] && res['status'] == 200)
      token = res['data']['token']
    end

    File.open("#{Rails.root}/tmp/token", 'w') {|f| f.write(token) } if token.present?
    token
  end

  def self.authenticate_by_admin
    dde2_configs = self.dde2_configs
    url = "#{self.dde2_url}/v1/authenticate"

    params = {'username' => 'admin', 'password' => 'admin'}

    res = JSON.parse(RestClient.post(url, params.to_json, :content_type => 'application/json'))
    token = nil
    if (res.present? && res['status'] && res['status'] == 200)
      token = res['data']['token']
    end

    token
  end

  def self.add_user(token)
    dde2_configs = self.dde2_configs
    url = "#{self.dde2_url}/v1/add_user"
    url = url.gsub(/\/\//, "//admin:admin@")
    response = RestClient.put(url,{
                  "username" => dde2_configs["dde_username"],  "password" => dde2_configs["dde_password"],
                  "application" => dde2_configs["application_name"], "site_code" => dde2_configs["site_code"],
                  "description" => "AnteNatal Clinic"
              }.to_json, :content_type => 'application/json')

    if response['status'] == 201
      return response['data']
    else
      return false
    end
  end

  def self.token
    self.validate_token(File.read("#{Rails.root}/tmp/token"))
  end

  def self.validate_token(token)
    url = "#{self.dde2_url}/v1/authenticated/#{token}"
    response = nil
    response = JSON.parse(RestClient.get(url)) rescue nil if !token.blank?

    if !response.blank? && response['status'] == 200
      return token
    else
      return self.authenticate
    end
  end

  def self.format_params(params, date)
    gender = (params['person']['gender'].match(/F/i)) ? "Female" : "Male"

    birthdate = nil
    if params['person']['age_estimate'].present?
      birthdate = Date.new(date.to_date.year - params['person']['age_estimate'].to_i, 7, 1).strftime("%Y-%m-%d")
    else
      params['person']['birth_month'] = params['person']['birth_month'].rjust(2, '0')
      params['person']['birth_day'] = params['person']['birth_day'].rjust(2, '0')
      birthdate = "#{params['person']['birth_year']}-#{params['person']['birth_month']}-#{params['person']['birth_day']}"
    end

    citizenship = params['person']['race']
    country_of_residence = params['person']['country_of_residence']
    ids = params['identifier'].present?  ? {
        'National id' => params['identifier']
    } : {}

    result = {
        "family_name"=> params['person']['names']['family_name'],
        "given_name"=> params['person']['names']['given_name'],
        "middle_name"=> (params['person']['names']['middle_name'] || "N/A"),
        "gender"=> gender,
        "birthdate"=> birthdate,
        "birthdate_estimated" => (params['person']['age_estimate'].blank? ? false : true),
        "identifiers"=> ids,
        "attributes" => {},
        "current_residence"=> params['person']['addresses']['address1'],
        "current_village" => params['person']['addresses']['city_village'],
        "current_ta"=> (params['filter']['t_a']),
        "current_district"=> params['person']['addresses']['state_province'],
        "home_village"=> params['person']['addresses']['neighborhood_cell'],
        "home_ta"=> params['person']['addresses']['county_district'],
        "home_district"=> params['person']['addresses']['address2']
    }
   
    
    if params['person']["occupation"].present?
      result["attributes"].merge!({"occupation" => params['person']["occupation"]})
    end

    if params['person']["cell_phone_number"].present?
      result["attributes"].merge!({"cell_phone_number" => params['person']["cell_phone_number"]})
    end

    if params['person']["office_phone_number"].present?
      result["attributes"].merge!({"office_phone_number" => params['person']["office_phone_number"]})
    end

    if params['person']["home_phone_number"].present?
      result["attributes"].merge!({"home_phone_number" => params['person']["home_phone_number"]})
    end

    if params['person']["citizenship"].present?
      result["attributes"].merge!({"citizenship" => params['person']["citizenship"]})
    end

    if params['person']["country_of_residence"].present?
     result["attributes"].merge!({"country_of_residence" => params['person']["country_of_residence"]})
    end
    
    if result['identifiers'].present?
      result['identifiers'].each do |k, v|
        if v.blank? || v.match(/^N\/A$|^null$|^undefined$|^nil$/i)
          result['identifiers'].delete(k)  unless [true, false].include?(v)
        end
      end
    end

    result.each do |k, v|
      if v.blank? || v.to_s.match(/^null$|^undefined$|^nil$/i)
        result.delete(k) unless [true, false].include?(v)
      end
    end
    
    result
  end

  def self.is_valid?(params)
    valid = true
    ['family_name', 'given_name', 'gender', 'birthdate', 'home_district'].each do |key|
      if params[key].blank? || params[key].to_s.strip.match(/^N\/A$|^null$|^undefined$|^nil$/i)
        valid = false
      end
    end
    if valid && !params['birthdate'].match(/\d{4}-\d{1,2}-\d{1,2}/)
      valid = false
    end

    if valid && !['Female', 'Male'].include?(params['gender'])
      valid = false
    end

    valid
  end

  def self.search_from_dde2(params)
    return [] if params['given_name'].blank? ||  params['family_name'].blank? ||
        params['gender'].blank?


    url = "#{self.dde2_url_with_auth}/v1/search_by_name_and_gender"
    params = {'given_name' => params['given_name'],
              'family_name' => params['family_name'],
              'gender' => ({'F' => 'Female', 'M' => 'Male'}[params['gender']] || params['gender'])
    }

    response = JSON.parse(RestClient.post(url, params.to_json, :content_type => 'application/json')) rescue nil

    if response.present?
      return response['data']['hits']
    else
      return false
    end
  end

  def self.create_from_dde2(params)
    url = "#{self.dde2_url_with_auth}/v1/add_patient"
    params['token'] = self.token
    data = {}

    RestClient.put(url, params.to_json, :content_type => 'application/json'){|response, request, result|
       response = JSON.parse(response) rescue response

      if response['status'] == 201
         data = response['data']
      elsif response['status'] == 409
        data = response
      end
    }
    data
  end

  def self.strip(hash)
    result = hash
    result['birthdate'] = result['birthdate'].to_date.strftime("%Y-%m-%d") rescue  result['birthdate']
    (result['attributes'] || {}).each do |k, v|
      if v.blank? || v.match(/^N\/A$|^null$|^undefined$|^nil$/i)
        result['attributes'].delete(k)  unless [true, false].include?(v)
      end
    end

    (result['identifiers'] || {}).each do |k, v|
      if v.blank? || v.match(/^N\/A$|^null$|^undefined$|^nil$/i)
        result['identifiers'].delete(k)  unless [true, false].include?(v)
      end
    end

    result.each do |k, v|
      if v.blank? || v.to_s.match(/^null$|^undefined$|^nil$/i)
        result.delete(k) unless [true, false].include?(v)
      end
    end
    result
  end


  def self.force_create_from_dde2(params, path)
    url = "#{self.dde2_url}#{path}"
    params['token'] = self.token
    params.delete_if{|k,v| ['npid', 'return_path'].include?(k)}

    data = {}
    RestClient.put(url, params.to_json, :content_type => 'application/json'){|response, request, result|
      response = JSON.parse(response) rescue response
      if response['status'] == 201
        data = response['data']
      end
    }
    data
  end

  def self.search_by_identifier(npid)

    url = "#{self.dde2_url}/v1/search_by_identifier/#{npid.strip}/#{self.token}"
    response = JSON.parse(RestClient.get(url)) rescue nil

    if response.present? && [200, 204].include?(response['status'])
      return response['data']['hits']
    else
      return []
    end
  end

  def self.search_all_by_identifier(npid)
    identifier = npid.gsub(/\-/, '').strip
    people = PatientIdentifier.find_all_by_identifier_and_identifier_type(identifier, 3).map{|id|
      id.patient.person
    } unless identifier.blank?

    return people unless people.blank?

    p = DDE2Service.search_by_identifier(identifier)
    return [] if p.blank?
    return "found duplicate identifiers" if p.count > 1

    p = p.first
    passed_national_id = p["npid"]

    unless passed_national_id.blank?
      patient = PatientIdentifier.find(:first,
                                       :conditions =>["voided = 0 AND identifier = ? AND identifier_type = 3",passed_national_id]).patient rescue nil
      return [patient.person] unless patient.blank?
    end

    birthdate_year = p["birthdate"].to_date.year
    birthdate_month = p["birthdate"].to_date.month
    birthdate_day = p["birthdate"].to_date.day
    birthdate_estimated = p["birthdate_estimated"]
    gender = p["gender"].match(/F/i) ? "Female" : "Male"
    passed = {
        "person"  =>{"age_estimate"      => birthdate_estimated,
                    "birth_month"       => birthdate_month ,
                    "addresses"         =>{"address1"=>p['addresses']["current_residence"],
                                         'township_division' => p['addresses']['current_ta'],
                                         "address2"=>p['addresses']["home_district"],
                                         "city_village"=>p['addresses']["current_village"],
                                         "state_province"=>p['addresses']["current_district"],
                                         "neighborhood_cell"=>p['addresses']["home_village"],
                                         "county_district"=>p['addresses']["home_ta"]},
                   "gender"            => gender ,
                   "patient"           =>{"identifiers"=>{"National id" => p["npid"]}},
                   "birth_day"         =>birthdate_day,
                   "names"             =>{"family_name"=>p['names']["family_name"],
                                         "given_name"=>p['names']["given_name"],
                                         "middle_name"=> (p['names']["middle_name"] || "")},
                   "birth_year"        =>birthdate_year
                      },
        "filter_district"=>"",
        "filter"=>{"region"=>"",
                   "t_a"=>""},
        "relation"=>""
    }

    if p['attributes'].present? && p['attributes']["occupation"].present?
      passed["person"].merge!("attributes" => {"occupation" => p['attributes']["occupation"]})
    end   

    if p['attributes'].present? && p['attributes']["home_phone_number"].present?
      passed["person"].merge!("attributes" => {"home_phone_number" => p['attributes']["home_phone_number"]})
    end 
    
    if p['attributes'].present? && p['attributes']["office_phone_number"].present?
      passed["person"].merge!("attributes" => {"office_phone_number" => p['attributes']["office_phone_number"]})
    end  

    if p['attributes'].present? && p['attributes']["cell_phone_number"].present?
      passed["person"].merge!("attributes" => {"cell_phone_number" => p['attributes']["cell_phone_number"]})
    end  
    
    if p['attributes'].present? && p['attributes']["citizenship"].present?
      passed["person"].merge!("attributes" => {"citizenship" => p['attributes']["citizenship"]})
    end   
    
    passed["person"].merge!("identifiers" => {"National id" => passed_national_id})

    return [PatientService.create_from_form(passed["person"])]
    return people
  end

  def self.update_local_from_dde2(data, person)
		name = person.names.last
		address = person.addresses.last
		
		name.update_attributes(
			:given_name => data['names']['given_name'],
			:middle_name => data['names']['middle_name'],
			:family_name => data['names']['family_name']
		)
		
		person.update_attributes(
			:gender => data['gender'],
			:birthdate => data['birthdate'],
			:birthdate_estimated => data['birthdate_estimated']
		)

		address.update_attributes(
			{"address1"=> (data['addresses']["current_residence"] rescue ""),
       'township_division' => (data['addresses']['current_ta'] rescue ""),
       "address2"=> (data['addresses']["home_district"] rescue ""),
       "city_village"=> (data['addresses']["current_village"] rescue ""),
       "state_province"=> (data['addresses']["current_district"] rescue ""),
       "neighborhood_cell"=> (data['addresses']["home_village"] rescue ""),
       "county_district"=> (data['addresses']["home_ta"] rescue "")}
		) 
		
		(data['attributes'] || {}).each {|k, v|
			next if v.blank? 
			type = PersonAttributeType.find_by_name(k.humanize).id rescue nil 
			next if type.blank?
			attribute = PersonAttribute.find_by_person_id_and_person_attribute_type_id(person.id, type)
			attribute = PersonAttribute.new if attribute.blank? 

			attribute.person_attribute_type_id = type
			attribute.person_id = person.id
			attribute.value = v
			attribute.save
		}
		true
	end 

  def self.update_local_demographics(data)
    data
  end

  def self.update_national_id(patient_bean, new_id)
        npid_type = PatientIdentifierType.find_by_name('National id').id
        npid = PatientIdentifier.find_by_identifier_and_identifier_type_and_patient_id(patient_bean.national_id,
                npid_type, patient_bean.patient_id)

        PatientIdentifier.create(
            :patient_id => npid.patient_id,
            :creator => User.current.id,
            :identifier => npid.identifier,
            :identifier_type => PatientIdentifierType.find_by_name('Old Identification Number').id
        )

        PatientIdentifier.create(
            :patient_id => npid.patient_id,
            :creator => User.current.id,
            :identifier =>  new_id,
            :identifier_type => npid_type
        )
  
        npid.update_attributes(
            :voided => true,
            :voided_by => User.current.id,
            :void_reason => 'Reassigned NPID',
            :date_voided => Time.now
        )
  end  

  def self.push_to_dde2(patient_bean)

    from_dde2 = self.search_by_identifier(patient_bean.national_id)

    if from_dde2.length > 0 && !patient_bean.national_id.strip.match(/^P\d+$/)
      return self.update_local_demographics(from_dde2[0])
    else
      result = {
          "family_name"=> patient_bean.last_name,
          "given_name"=> patient_bean.first_name,
          "gender"=> patient_bean.sex,
          "attributes"=> {
              "occupation"=> (patient_bean.occupation rescue ""),
              "cell_phone_number"=> (patient_bean.cell_phone_number rescue ""),
              "citizenship" => (patient_bean.citizenship rescue "")
          },
          "birthdate" => (Person.find(patient_bean.person_id).birthdate.to_date.strftime('%Y-%m-%d') rescue nil),
          "birthdate_estimated" => (patient_bean.birthdate_estimated.to_s == '0' ? false : true),
          "identifiers"=> {
              'Old Identification Number' => patient_bean.national_id
          },
          "current_residence"=> patient_bean.landmark,
          "current_village"=> patient_bean.current_residence,
          "current_district"=>  patient_bean.current_district,
          "home_village"=> patient_bean.home_village,
          "home_ta"=> patient_bean.traditional_authority,
          "home_district"=> patient_bean.home_district
      }

      result['home_district'] = 'Other' if result['home_district'].blank?

      (result['attributes'] || {}).each do |k, v|
        if v.blank? || v.match(/^N\/A$|^null$|^undefined$|^nil$/i)
          result['attributes'].delete(k)  unless [true, false].include?(v)
        end
      end

      (result['identifiers'] || {}).each do |k, v|
        if v.blank? || v.match(/^N\/A$|^null$|^undefined$|^nil$/i)
          result['identifiers'].delete(k)  unless [true, false].include?(v)
        end
      end

      result.each do |k, v|
        if v.blank? || v.to_s.match(/^null$|^undefined$|^nil$/i)
          result.delete(k) unless [true, false].include?(v)
        end
      end

      data = self.create_from_dde2(result)

      if data.present? && data['return_path']
        data = self.force_create_from_dde2(result, data['return_path'])
      end

      if !data.blank?
        npid_type = PatientIdentifierType.find_by_name('National id').id
        npid = PatientIdentifier.find_by_identifier_and_identifier_type_and_patient_id(patient_bean.national_id,
                npid_type, patient_bean.patient_id)

        PatientIdentifier.create(
            :patient_id => npid.patient_id,
            :creator => User.current.id,
            :identifier => npid.identifier,
            :identifier_type => PatientIdentifierType.find_by_name('Old Identification Number').id
        )

        PatientIdentifier.create(
            :patient_id => npid.patient_id,
            :creator => User.current.id,
            :identifier =>  data['npid'],
            :identifier_type => npid_type
        )
        
        npid.update_attributes(
            :voided => true,
            :voided_by => User.current.id,
            :void_reason => 'Reassigned NPID',
            :date_voided => Time.now
        )

      end

      data
    end
  end

  def self.update_demographics(patient_bean)

    birthdate = nil
    birthdate_estimated = false
    if patient_bean.birthdate_estimated.present? && patient_bean.birthdate_estimated == 1
      if patient_bean.birth_date.split("/").second == "???"
        birthdate = Date.new(patient_bean.birth_date.split("/").third.to_i,7,1).strftime("%Y-%m-%d")
        birthdate_estimated = true
      elsif patient_bean.birth_date.split("/").first == "??"
        birthdate = Date.new(patient_bean.birth_date.split("/").third.to_i,
                             patient_bean.birth_date.split("/").second.to_i,1).strftime("%Y-%m-%d")
        birthdate_estimated = true               
      else
        birthdate = patient_bean.birth_date.to_date.strftime("%Y-%m-%d")
        raise birth_date.inspect
      end  
    else   
      birthdate = patient_bean.birth_date.to_date.strftime("%Y-%m-%d")
    end

    result = {
        "npid" => patient_bean.national_id,
        "family_name"=> patient_bean.last_name,
        "given_name"=> patient_bean.first_name,
        "gender"=> patient_bean.sex,
        "birthdate"=> birthdate,
        "birthdate_estimated" => birthdate_estimated,
        "home_district"=> (patient_bean.home_district || 'Other'),
        "attributes" => {},
        "token" => self.token
    }
      
   if patient_bean.landmark.present?
     result.merge!({"current_residence" => patient_bean.landmark })
   end

   if patient_bean.current_residence.present?
     result.merge!({"current_village" => patient_bean.current_residence })
   end

   if patient_bean.current_district.present?
     result.merge!({"current_district" => patient_bean.current_district })
   end

   if patient_bean.home_village.present?
     result.merge!({"home_village" => patient_bean.home_village })
   end

   if patient_bean.traditional_authority.present?
     result.merge!({"home_ta" => patient_bean.traditional_authority })
   end

   if patient_bean.home_district.present?
     result.merge!({"home_district" => patient_bean.home_district })
   end

   if patient_bean.occupation.present?
     result["attributes"].merge!({"occupation" => patient_bean.occupation})
   end

   if patient_bean.cell_phone_number.present?
     result["attributes"].merge!({"cell_phone_number" => patient_bean.cell_phone_number})
   end

   if patient_bean.office_phone_number.present?
     result["attributes"].merge!({"office_phone_number" => patient_bean.office_phone_number})
   end

   if patient_bean.home_phone_number.present?
    result["attributes"].merge!({"home_phone_number" => patient_bean.home_phone_number})
   end

   if patient_bean.citizenship.present?
     result["attributes"].merge!({"citizenship" => patient_bean.citizenship})
   end

   if patient_bean.country_of_residence.present?
     result["attributes"].merge! ({"country_of_residence" => patient_bean.country_of_residence})
   end
   
    data = nil
    url = "#{self.dde2_url}/v1/update_patient"

    response = RestClient.post(url, result.to_json, :content_type => 'application/json')
    response = JSON.parse(response) rescue response

    if (response['status'] == 201 rescue false)
        data =  true
      elsif (response['status'] == 409 rescue false)
        data = response['data']['hits']
      end


    data
  end

  def self.mark_duplicate(npid, token)
    return false if npid.blank?
    token = self.validate_token(token)
    return false if !token || token.blank?

    url = "#{self.dde2_url}/v1/void_patient/#{npid}/#{token}"
    response = JSON.parse(RestClient.get(url))

    if response['status'] == 200
      return response['data']
    else
      return false
    end
  end

  def self.create_from_form(params)
    params = params['person']
    return nil if params.blank?
    address_params = params["addresses"]
    names_params = params["names"]
    params_to_process = params.reject{|key,value| key.match(/addresses|patient|names|attributes/) }
    person_params = params_to_process.reject{|key,value| key.match(/identifiers|attributes/) }

    if person_params["gender"].to_s == "Female"
      person_params["gender"] = 'F'
    elsif person_params["gender"].to_s == "Male"
      person_params["gender"] = 'M'
    end

    person = Person.create(person_params)
    person.birthdate_estimated = person_params['birthdate_estimated'].to_i
    person.save

    person.names.create(names_params)
    person.addresses.create(address_params) unless address_params.empty? rescue nil
    
    if params['attributes'].present?
      params['attributes'].each do |type, value|
        person.person_attributes.create(
            :person_attribute_type_id => PersonAttributeType.find_by_name(type.humanize).person_attribute_type_id,
            :value => value) unless value.blank? rescue nil
      end
    end

    patient = person.create_patient
    if params['identifiers'].present?
      params["identifiers"].each{|identifier_type_name, identifier|

        next if identifier.blank?
        identifier_type = PatientIdentifierType.find_by_name(identifier_type_name) || PatientIdentifierType.find_by_name("Unknown id")
        patient.patient_identifiers.create("identifier" => identifier, "identifier_type" => identifier_type.patient_identifier_type_id)
      } if params["identifiers"]
    end
    return person
  end
end

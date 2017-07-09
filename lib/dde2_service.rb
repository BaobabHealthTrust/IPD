=begin
  Things to watch out for:

  1. The patient_identifier model is supposed to have it's after_save method
     changed to check if there is a DDE server to refer to first for this to work
  2. add the the hook after successifully searching for a patient as follows:

        patient = DDEService::Patient.new(found_person.patient)

        patient.check_old_national_id(params[:identifier])
  3. this module runs as all the other services. It had to have some of it's methods
      replicated for local use to allow for independence when being used in systems
      that don't need the other libraries as well as customisation of some methods for its use
=end

module DDE2Service

  class Patient

    attr_accessor :patient, :person

    def initialize(patient)
      self.patient = patient
      self.person = self.patient.person
    end

    def get_full_attribute(attribute)
      PersonAttribute.find(:first,:conditions =>["voided = 0 AND person_attribute_type_id = ? AND person_id = ?",
          PersonAttributeType.find_by_name(attribute).id,self.person.id]) rescue nil
    end

    def set_attribute(attribute, value)
      PersonAttribute.create(:person_id => self.person.person_id, :value => value,
        :person_attribute_type_id => (PersonAttributeType.find_by_name(attribute).id))
    end

    def get_full_identifier(identifier)
      PatientIdentifier.find(:first,:conditions =>["voided = 0 AND identifier_type = ? AND patient_id = ?",
          PatientIdentifierType.find_by_name(identifier).id, self.patient.id]) rescue nil
    end

    def set_identifier(identifier, value)
      PatientIdentifier.create(:patient_id => self.patient.patient_id, :identifier => value,
        :identifier_type => (PatientIdentifierType.find_by_name(identifier).id))
    end

    def name
      "#{self.person.names.first.given_name} #{self.person.names.first.family_name}".titleize rescue nil
    end

    def first_name
      "#{self.person.names.first.given_name}".titleize rescue nil
    end

    def last_name
      "#{self.person.names.first.family_name}".titleize rescue nil
    end

    def middle_name
      "#{self.person.names.first.middle_name}".titleize rescue nil
    end

    def maiden_name
      "#{self.person.names.first.family_name2}".titleize rescue nil
    end

    def current_address2
      "#{self.person.addresses.last.city_village}" rescue nil
    end

    def current_address1
      "#{self.person.addresses.last.county_district}" rescue nil
    end

    def current_district
      "#{self.person.addresses.last.state_province}" rescue nil
    end

    def current_address
      "#{self.current_address1}, #{self.current_address2}, #{self.current_district}" rescue nil
    end

    def home_district
      "#{self.person.addresses.last.address2}" rescue nil
    end

    def home_ta
      "#{self.person.addresses.last.county_district}" rescue nil
    end

    def home_village
      "#{self.person.addresses.last.neighborhood_cell}" rescue nil
    end

    def national_id(force = true)
      id = self.patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
      return id unless force
      id ||= PatientIdentifierType.find_by_name("National id").next_identifier(:patient => self.patient).identifier
      id
    end

    def self.set_birthdate_by_age(person, age, today = Date.today)
        person.birthdate = Date.new(today.year - age.to_i, 7, 1)
        person.birthdate_estimated = 1
    end

    def self.set_birthdate(person, year = nil, month = nil, day = nil)
        raise "No year passed for estimated birthdate" if year.nil?

        # Handle months by name or number (split this out to a date method)
        month_i = (month || 0).to_i
        month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
        month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?

        if month_i == 0 || month == "Unknown"
        person.birthdate = Date.new(year.to_i,7,1)
        person.birthdate_estimated = 1
        elsif day.blank? || day == "Unknown" || day == 0
        person.birthdate = Date.new(year.to_i,month_i,15)
        person.birthdate_estimated = 1
        else
        person.birthdate = Date.new(year.to_i,month_i,day.to_i)
        person.birthdate_estimated = 0
        end
   end

  def check_old_national_id(identifier)
        if (identifier.to_s.strip.length != 6 and identifier == self.national_id)
           replaced_national_id = replace_old_national_id(identifier)
           return replaced_national_id
        elsif (identifier.to_s.strip.length >= 6 and identifier != self.national_id and self.national_id.length != 6)
           replaced_national_id = replace_old_national_id(self.national_id)
           return replaced_national_id
        else
           return false
        end
   end

   def replace_old_national_id(identifier)
        person = JSON.parse(DDE2Service.search_by_identifier(identifier)) rescue nil
        
        passed_national_id = (person["data"]["hits"].first["npid"]) rescue nil
        
    person = {"person" => {
          "birthdate_estimated" => (self.person.birthdate_estimated rescue nil),
          "gender" => (self.person.gender rescue nil),
          "birthdate" => (self.person.birthdate rescue nil),
          "birth_year" => (self.person.birthdate.to_date.year rescue nil),
          "birth_month" => (self.person.birthdate.to_date.month rescue nil),
          "birth_day" => (self.person.birthdate.to_date.date rescue nil),
          "names" => {
            "given_name" => self.first_name,
            "family_name" => self.last_name
          },
          "patient" => {
            "identifiers" => {
              "old_identification_number" => identifier
            }
          },
          "attributes" => {
            "occupation" => (self.get_full_attribute("Occupation").value rescue nil),
            "cell_phone_number" => (self.get_full_attribute("Cell Phone Number").value rescue nil),
            "citizenship" => (self.get_full_attribute("Citizenship").value rescue nil),
            "race" => (self.get_full_attribute("Race").value rescue nil)
          },
          "addresses" => {
            "address1" => (self.current_address1 rescue nil),
            "address2" => (self.home_district rescue nil),
            "city_village" => (self.current_address2 rescue nil),
            "county_district" => (self.home_ta rescue nil),
            "state_province" => (self.current_district rescue nil),
            "neighborhood_cell" => (self.home_village rescue nil)
          }
        }
      }

      current_national_id = self.get_full_identifier("National id")
      national_id = DDE2Service.create_patient_from_dde2(person, true)
      self.set_identifier("National id", national_id)
      self.set_identifier("Old Identification Number", current_national_id.identifier)
      current_national_id.void("National ID version change")
      return true
    end
  end


    def self.create_patient_from_dde2(params, dont_recreate_local=false)
	  address_params = params["person"]["addresses"]
		names_params = params["person"]["names"]
		patient_params = params["person"]["patient"]
    birthday_params = params["person"]
    old_identifier = params["person"]["patient"]["identifiers"]["old_identification_number"]
		params_to_process = params.reject{|key,value|
      key.match(/identifiers|addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy/)
    }
		birthday_params = params_to_process["person"].reject{|key,value| key.match(/gender/) }
		person_params = params_to_process["person"].reject{|key,value| key.match(/birth_|age_estimate|occupation/) }


		if person_params["gender"].to_s == "Female"
      person_params["gender"] = 'F'
		elsif person_params["gender"].to_s == "Male"
      person_params["gender"] = 'M'
		end

		unless birthday_params.empty?
		  if birthday_params["birth_year"] == "Unknown"
			  birthdate = Date.new(Date.today.year - birthday_params["age_estimate"].to_i, 7, 1)
        birthdate_estimated = 1
		  else
			  year = birthday_params["birth_year"]
        month = birthday_params["birth_month"]
        day = birthday_params["birth_day"]

        month_i = (month || 0).to_i
        month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
        month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?

        if month_i == 0 || month == "Unknown"
          birthdate = Date.new(year.to_i,7,1)
          birthdate_estimated = 1
        elsif day.blank? || day == "Unknown" || day == 0
          birthdate = Date.new(year.to_i,month_i,15)
          birthdate_estimated = 1
        else
          birthdate = Date.new(year.to_i,month_i,day.to_i)
          birthdate_estimated = 0
        end
		  end
    else
      birthdate_estimated = 0
		end

        passed_params = { "given_name" => names_params["given_name"], 
                          "family_name" => names_params["family_name"],
                          "gender" => (person_params["gender"] == 'M' ? 'Male' : 'Female'),
                          "birthdate" => birthdate,
                          "birthdate_estimated" => (birthdate_estimated == 0 ? false : true),
                          "attributes" => {"occupation"=> params["person"]["occupation"],
                                          "cell_phone_number" => params["person"]["cell_phone_number"]},
                          "current_residence" => address_params["neighborhood_cell"],
                          "current_ta" => address_params["city_village"],
                          "current_district" => address_params["county_district"],
                          "home_village" => address_params["address1"],
                          "home_ta" => address_params["address2"],
                          "home_district" => address_params["state_province"],
                          "identifiers" => {"old_identification_number"=> old_identifier}}

    unless params["remote"]
      national_id = DDE2Service.add_new_patient(passed_params)
    else
      national_id = params["person"]["patient"]["identifiers"]["National id"]
      national_id = params["person"]["value"] if national_id.blank? rescue nil
      return national_id
    end


    if (dont_recreate_local == false)
      person = self.create_from_form(params["person"])

      identifier_type = PatientIdentifierType.find_by_name("National id") || PatientIdentifierType.find_by_name("Unknown id")

      person.patient.patient_identifiers.create("identifier" => national_id,
        "identifier_type" => identifier_type.patient_identifier_type_id) unless national_id.blank?
      return person
    else

      return national_id
    end
  end
  
  def self.create_from_form(params)

		address_params = params["addresses"]
		names_params = params["names"]
		patient_params = params["patient"]
		params_to_process = params.reject{|key,value| key.match(/addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy/) }
		birthday_params = params_to_process.reject{|key,value| key.match(/gender/) }
		person_params = params_to_process.reject{|key,value| key.match(/birth_|age_estimate|occupation|identifiers|attributes/) }

		if person_params["gender"].to_s == "Female"
      person_params["gender"] = 'F'
		elsif person_params["gender"].to_s == "Male"
      person_params["gender"] = 'M'
		end

		person = Person.create(person_params)

		unless birthday_params.empty?
		  if birthday_params["birth_year"] == "Unknown"
        self.set_birthdate_by_age(person, birthday_params["age_estimate"], person.session_datetime || Date.today)
		  else
        self.set_birthdate(person, birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
		  end
		end

		person.save

		person.names.create(names_params)
		person.addresses.create(address_params) unless address_params.empty? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Occupation").person_attribute_type_id,
		  :value => params["occupation"]) unless params["occupation"].blank? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Cell Phone Number").person_attribute_type_id,
		  :value => params["cell_phone_number"]) unless params["cell_phone_number"].blank? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Office Phone Number").person_attribute_type_id,
		  :value => params["office_phone_number"]) unless params["office_phone_number"].blank? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Home Phone Number").person_attribute_type_id,
		  :value => params["home_phone_number"]) unless params["home_phone_number"].blank? rescue nil

    # TODO handle the birthplace attribute

		if (!patient_params.nil?)
		  patient = person.create_patient

		  patient_params["identifiers"].each{|identifier_type_name, identifier|
        next if identifier.blank?
        identifier_type = PatientIdentifierType.find_by_name(identifier_type_name) || PatientIdentifierType.find_by_name("Unknown id")
        patient.patient_identifiers.create("identifier" => identifier, "identifier_type" => identifier_type.patient_identifier_type_id)
		  } if patient_params["identifiers"]

		  # This might actually be a national id, but currently we wouldn't know
		  #patient.patient_identifiers.create("identifier" => patient_params["identifier"], "identifier_type" => PatientIdentifierType.find_by_name("Unknown id")) unless params["identifier"].blank?
		end

		return person
	end


  def self.update_demographics(patient_bean)
     update_existing_patient(patient_bean)
  end

  def self.authenticate_user
      user_params = {"username" => ServerConnection.username, 
                    "password" => ServerConnection.password}
                
      response = RestClient::Request.execute(:method => :post, 
                                            :url => API.authenticate_user_url, 
                                            :payload => user_params.to_json, 
                                            :headers => {:accept => :json,
                                                        :content_type => :json}
                                            )
      return response                                       
                                                      
  end

  def self.add_user

      user_params = {"username" => ServerConnection.username, 
                      "password" => ServerConnection.password,
                      "application" => ClientConnection.name,
                      "site_code" => ClientConnection.code,
                      "token" => ClientConnection.token,
                      "description" => ClientConnection.description}

      response = RestClient::Request.execute(:method => :put, 
                                            :url => API.add_user_url, 
                                            :payload => user_params.to_json, 
                                            :headers => {:accept => :json,
                                                        :content_type => :json}
                                            )
      return response   
  end

  def self.check_if_token_authenticated

      response = RestClient::Request.execute(:method => :get, 
                                            :url => API.check_if_token_authenticated_url,  
                                            :headers => {:accept => :json,
                                                        :content_type => :json}
                                            )
      return response   
  
  end  
    
  def self.add_new_patient(person)
    
    person_params = {
                      "family_name" => person["family_name"], 
                      "given_name" => person["given_name"], 
                      "gender" => person["gender"],
                      "attributes" => {},
                      "birthdate" => person["birthdate"].strftime("%Y-%m-%d"),
                      "identifiers" => {},
                      "birthdate_estimated" => person["birthdate_estimated"],
                      "current_residence" => "N/A",
                      "current_village" => "N/A",
                      "current_ta" => person["current_ta"].squish,
                      "current_district" => person["current_district"],
                      "home_village" => "N/A",
                      "home_ta" => person["home_ta"],
                      "home_district" => person["home_district"]
                    }

    response = JSON.parse(RestClient.put(API.add_new_patient_url, 
                                          person_params.to_json,
                                          :content_type => "application/json"))  

    if response && response["status"] == 201
      return response["data"]["npid"]
    else
      return "#{response['status']} : #{response['message']}"
    end 
    
  end 

  def self.search_by_identifier(identifier)
      if identifier.blank? && identifier.length != 6 
        raise "Invalid NPID"
      end  

      response = RestClient::Request.execute(:method => :get, 
                                              :url => API.search_by_identifier_url(identifier),  
                                              :headers => {:accept => :json,
                                                          :content_type => :json}
                                              )
      return response   
  end
  
  def self.search_by_name_and_gender(given_name, family_name, gender)

    if given_name.blank?
        raise "Invalid  Given Name" 
    end 

    if family_name.blank?
      raise "Invalid Family Name"
    end

    if gender.blank? || gender.length < 2
      raise "Invalid Gender"
    end    
      
    person_params = {"given_name" => given_name, 
                      "family_name" => family_name,
                      "gender" => gender}

    response = RestClient::Request.execute(:method => :post, 
                                            :url => API.search_by_name_and_gender_url, 
                                            :payload => person_params.to_json, 
                                            :headers => {:accept => :json,
                                                        :content_type => :json}
                                            )
    return response   

  end

  def self.advanced_patient_search(given_name, family_name, gender,birthdate, home_district)

    if given_name.blank?
        raise "Invalid  Given Name" 
    end 

    if family_name.blank?
      raise "Invalid Family Name"
    end

    if gender.blank? || gender.length < 2
      raise "Invalid Gender"
    end

    if birthdate.blank? || !Date.strptime(birthdate, "%Y/%m/%d")
      raise "Invalid Birthdate"
    end

    if home_district.blank? || home_district.length < 3
      raise "Invalid Home District"
    end     
      
    person_params = {"given_name" => give_name, 
                      "family_name" => family_name,
                      "gender" => gender,
                      "birthdate" => birthdate,
                      "home_district" => home_district,
                      "token" => ClientConnection.token}

    response = RestClient::Request.execute(:method => :post, 
                                            :url => API.advanced_patient_search_url, 
                                            :payload => person_params.to_json, 
                                            :headers => {:accept => :json,
                                                        :content_type => :json}
                                            )
    return response   
  end     

  def self.update_existing_patient(person)     
    #raise person.inspect
    person_params = { "npid" => person.national_id, 
                      "given_name" => person.first_name, 
                      "family_name" => person.last_name,
                      "gender" => person.sex,
                      "birthdate" => person.birthdate,
                      "birthdate_estimated" => person.birthdate_estimated,
                      "attributes" => {"occupation"=> (person.occupation rescue ""),
                                        "cell_phone_number" => (person.cell_phone_number rescue ""),
                                        "citizenship" => (person.citizenship rescue ""),
                                        "race" => (person.race rescue "")},
                      "current_residence" => person.current_residence,
                      "current_ta" => (person.current_ta rescue "N/A"),
                      "current_district" => person.current_district,
                      "home_village" => person.home_village,
                      "home_ta" => (person.home_ta rescue "N/A"),
                      "home_district" => person.home_district,
                      "identifiers" => {"identifiers"=> {"national_id" => person.national_id}}}
    
    response = RestClient::Request.execute(:method => :post, 
                                            :url => API.update_existing_patient_url, 
                                            :payload => person_params.to_json, 
                                            :headers => {:accept => :json,
                                                        :content_type => :json} )
    return response   

  end

  def self.merge_patients(primary, secondary)
    attributes = {}
    identifiers = {}
  
    person_params = {"primary_record" =>{ "npid" => primary.npid, 
                                          "given_name" => primary.given_name, 
                                          "family_name" => primary.family_name,
                                          "gender" => primary.gender,
                                          "birthdate" => primary.birthdate,
                                          "birthdate_estimated" => primary.birthdate_estimated,
                                          "attributes" => attributes,
                                          "current_residence" => primary.current_address,
                                          "current_ta" => primary.current_ta,
                                          "current_district" => primary.current_district,
                                          "home_village" => primary.home_village,
                                          "home_ta" => primary.home_ta,
                                          "home_district" => primary.home_district,
                                          "identifiers" => identifiers,
                                          "token" => ClientConnection.token}}
      

      attributes = {}
      identifiers = {}

      secondary_params = {"secondary_record" =>{ "npid" => secondary.npid, 
                                                  "given_name" => secondary.given_name, 
                                                  "family_name" => secondary.family_name,
                                                  "gender" => secondary.gender,
                                                  "birthdate" => secondary.birthdate,
                                                  "birthdate_estimated" => secondary.birthdate_estimated,
                                                  "attributes" => attributes,
                                                  "current_residence" => secondary.current_address,
                                                  "current_ta" => secondary.current_ta,
                                                  "current_district" => secondary.current_district,
                                                  "home_village" => secondary.home_village,
                                                  "home_ta" => secondary.home_ta,
                                                  "home_district" => secondary.home_district,
                                                  "identifiers" => identifiers,
                                                  "token" => ClientConnection.token}}
        person_params.merge! secondary_params                                           

        response = RestClient::Request.execute(:method => :post, 
                                              :url => API.merge_patients_url, 
                                              :payload => person_params.to_json, 
                                              :headers => {:accept => :json,
                                                            :content_type => :json}
                                            )
    return response 

  end

  def self.mark_record_as_duplicate(identifier)

    if identifier.blank? && identifier.length != 6 
        raise "Invalid NPID"
    end  

    response = RestClient::Request.execute(:method => :delete, 
                                            :url => API.mark_record_as_duplicate_url(identifier),  
                                            :headers => {:accept => :json,
                                                        :content_type => :json}
                                            )
    return response

  end  
  
  class ServerConnection
    def self.address
      if basic_http_auth?
        server_ip = GlobalProperty.find_by_property("dde2_server_ip").property_value rescue ""
        return "http://#{username}:#{password}@#{server_ip}"
      else
          return GlobalProperty.find_by_property("dde2_server_ip").property_value rescue ""
      end  
      
    end

    def self.username
      return GlobalProperty.find_by_property("dde2_server_username").property_value rescue ""
    end    

    def self.password
      return GlobalProperty.find_by_property("dde2_server_password").property_value rescue ""
    end
    
    def self.basic_http_auth?
        return GlobalProperty.find_by_property("dde2_basic_http_auth").property_value rescue true
    end  

  end

  class ClientConnection
    def self.name
      return "Registration"
    end
    
    def self.code
      return "KCH"
    end
    
    def self.description
      return "Patient Registration application at Kamuzu Central Hospital"
    end

    def self.token
      return "c98NtYoucP3X"
    end
  end  

  class API

    @version = "v1"

    def self.authenticate_user_url
      return "#{ServerConnection.address}/#{@version}/authenticate"
    end
    
    def self.add_user_url
      return "#{ServerConnection.address}/#{@version}/add_user"
    end
    
    def self.check_if_token_authenticated_url
      return "#{ServerConnection.address}/#{@version}/authenticated/#{ClientConnection.token}"
    end

    def self.search_by_identifier_url(identifier)
      return "#{ServerConnection.address}/#{@version}/search_by_identifier/#{identifier}/#{ClientConnection.token}"
    end

    def self.search_by_name_and_gender_url
      return "#{ServerConnection.address}/#{@version}/search_by_name_and_gender"
    end

    def self.advanced_patient_search_url
      return "#{ServerConnection.address}/#{@version}/advanced_patient_search"
    end

    def self.mark_record_as_duplicate_url(identifier)
      return "#{ServerConnection.address}/#{@version}/void_patient/#{identifier}/#{ClientConnection.token}"
    end  

    def self.add_new_patient_url
        return "#{ServerConnection.address}/#{@version}/add_patient"
    end

    def self.update_existing_patient_url
        return "#{ServerConnection.address}/#{@version}/update_patient"
    end

    def self.merge_patients_url
        return "#{ServerConnection.address}/#{@version}/merge_records"
    end  

    def self.headers
      return {:accept => :json, :content_type => :json}
    end
  end         

 end


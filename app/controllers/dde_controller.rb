require "rest-client"

class DdeController < ApplicationController

  def index
    session[:cohort] = nil

    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}

    application_name = @settings["application_name"].strip rescue ""
    return_uri = session[:return_uri]

    if !return_uri.blank? && (application_name.downcase.match("bart") || application_name.downcase.strip == "art")
      session[:return_uri] = []
      redirect_to return_uri.to_s
      return
    end

    @facility = Location.current_health_center.name rescue ''

    @location = Location.find(session[:location_id]).name rescue ""

    @date = session[:datetime].to_date rescue Date.today.to_date

    @person = Person.find_by_person_id(current_user.person_id) rescue nil

    @user = PatientService.name(@person) rescue nil

    @roles = current_user.user_roles.collect { |r| r.role } rescue []

    render :template => 'dde/index', :layout => false
  end

  def search
    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}

    @globals = YAML.load_file("#{Rails.root}/config/globals.yml")[Rails.env] rescue {}

    render :layout => false
  end

  def new
    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}
  end

  def process_result

    json = JSON.parse(params["person"]) rescue {}

    if (json["patient"]["identifiers"].class.to_s.downcase == "hash" rescue false)

      tmp = json["patient"]["identifiers"]

      json["patient"]["identifiers"] = []

      tmp.each do |key, value|

        json["patient"]["identifiers"] << {key => value}

      end

    end

    patient_id = DDE.search_and_or_create(json.to_json) # rescue nil

    # raise patient_id.inspect

    json = JSON.parse(params["person"]) rescue {}

    patient = Patient.find(patient_id) rescue nil

    print_and_redirect("/patients/national_id_label?patient_id=#{patient_id}", next_task(patient)) and return if !patient.blank? and (json["print_barcode"] rescue false)

    # redirect_to "/encounters/new/registration?patient_id=#{patient_id}" and return if !patient_id.blank?

    redirect_to next_task(patient) and return if !patient.blank?

    flash["error"] = "Sorry! Something went wrong. Failed to process properly!"

    redirect_to "/clinic" and return

  end

  def process_data
    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}

    params[:id] = params[:id].strip.gsub(/\s/, "").gsub(/\-/, "") rescue params[:id]

    patient = PatientIdentifier.find_by_identifier(params[:id]).patient rescue nil

    national_id = ((patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil) || params[:id])

    name = patient.person.names.last rescue nil

    address = patient.person.addresses.last rescue nil

    person = {
        "national_id" => national_id,
        "application" => "#{@settings["application_name"]}",
        "site_code" => "#{@settings["site_code"]}",
        "return_path" => "http://#{request.host_with_port}/process_result",
        "patient_id" => (patient.patient_id rescue nil),
        "names" =>
            {
                "family_name" => (name.family_name rescue nil),
                "given_name" => (name.given_name rescue nil),
                "middle_name" => (name.middle_name rescue nil),
                "maiden_name" => (name.family_name2 rescue nil)
            },
        "gender" => (patient.person.gender rescue nil),
        "person_attributes" => {
            "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
            "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
            "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
            "office_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Office Phone Number").id).value rescue nil),
            "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
            "country_of_residence" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Country of Residence").id).value rescue nil),
            "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
        },
        "birthdate" => (patient.person.birthdate rescue nil),
        "patient" => {
            "identifiers" => (patient.patient_identifiers.collect { |id| {id.type.name => id.identifier} if id.type.name.downcase != "national id" }.delete_if { |x| x.nil? } rescue [])
        },
        "birthdate_estimated" => ((patient.person.birthdate_estimated rescue 0).to_s.strip == '1' ? true : false),
        "addresses" => {
            "current_residence" => (address.address1 rescue nil),
            "current_village" => (address.city_village rescue nil),
            "current_ta" => (address.township_division rescue nil),
            "current_district" => (address.state_province rescue nil),
            "home_village" => (address.neighborhood_cell rescue nil),
            "home_ta" => (address.county_district rescue nil),
            "home_district" => (address.address2 rescue nil)
        }
    }

    render :text => person.to_json
  end

  def search_name

    result = {}

    json = {"results" => []}

    Person.find(:all, :joins => [:names], :conditions => ["given_name = ? AND family_name = ? AND gender = ?", params["given_name"], params["family_name"], params["gender"]]).each do |person|

      json["results"] << {
          "uuid" => person.id,
          "person" => {
              "display" => ("#{person.names.last.given_name} #{person.names.last.family_name}" rescue nil),
              "age" => ((Date.today - person.birthdate.to_date).to_i / 365 rescue nil),
              "birthdateEstimated" => ((person.birthdate_estimated.to_s.strip == '1' ? true : false) rescue false),
              "gender" => (person.gender rescue nil),
              "preferredAddress" => {
                  "cityVillage" => (person.addresses.last.city_village rescue nil)
              }
          },
          "identifiers" => person.patient.patient_identifiers.collect { |id|
            {
                "identifier" => (id.identifier rescue "Unknown"),
                "identifierType" => {
                    "display" => (id.type.name rescue "Unknown")
                }
            }
          }
      }

    end

    # raise json.inspect

    json["results"].each do |o|

      person = {
          :uuid => (o["uuid"] rescue nil),
          :name => (o["person"]["display"] rescue nil),
          :age => (o["person"]["age"] rescue nil),
          :estimated => (o["person"]["birthdateEstimated"] rescue nil),
          :identifiers => o["identifiers"].collect { |id|
            {
                :identifier => (id["identifier"] rescue nil),
                :idtype => (id["identifierType"]["display"] rescue nil)
            }
          },
          :gender => (o["person"]["gender"] rescue nil),
          :village => (o["person"]["preferredAddress"]["cityVillage"] rescue nil)
      }

      result[o["uuid"]] = person

    end

    render :text => result.to_json and return

  end

  def new_patient

    settings = YAML.load_file("#{Rails.root}/config/globals.yml")[Rails.env] rescue {}

    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}

    @show_middle_name = (settings["show_middle_name"] == true ? true : false) rescue false

    @show_maiden_name = (settings["show_maiden_name"] == true ? true : false) rescue false

    @show_birthyear = (settings["show_birthyear"] == true ? true : false) rescue false

    @show_birthmonth = (settings["show_birthmonth"] == true ? true : false) rescue false

    @show_birthdate = (settings["show_birthdate"] == true ? true : false) rescue false

    @show_age = (settings["show_age"] == true ? true : false) rescue false

    @show_region_of_origin = (settings["show_region_of_origin"] == true ? true : false) rescue false

    @show_district_of_origin = (settings["show_district_of_origin"] == true ? true : false) rescue false

    @show_t_a_of_origin = (settings["show_t_a_of_origin"] == true ? true : false) rescue false

    @show_home_village = (settings["show_home_village"] == true ? true : false) rescue false

    @show_current_region = (settings["show_current_region"] == true ? true : false) rescue false

    @show_current_district = (settings["show_current_district"] == true ? true : false) rescue false

    @show_current_t_a = (settings["show_current_t_a"] == true ? true : false) rescue false

    @show_current_village = (settings["show_current_village"] == true ? true : false) rescue false

    @show_current_landmark = (settings["show_current_landmark"] == true ? true : false) rescue false

    @show_cell_phone_number = (settings["show_cell_phone_number"] == true ? true : false) rescue false

    @show_office_phone_number = (settings["show_office_phone_number"] == true ? true : false) rescue false

    @show_home_phone_number = (settings["show_home_phone_number"] == true ? true : false) rescue false

    @show_occupation = (settings["show_occupation"] == true ? true : false) rescue false

    @show_nationality = (settings["show_nationality"] == true ? true : false) rescue false

    @occupations = ['','Driver','Housewife','Messenger','Business','Farmer','Salesperson','Teacher',
                    'Student','Security guard','Domestic worker', 'Police','Office worker',
                    'Preschool child','Mechanic','Prisoner','Craftsman','Healthcare Worker','Soldier'].sort.concat(["Other","Unknown"])

    @destination = request.referrer

  end

  def edit_patient
    if params[:id].blank?
      person_id = params[:patient_id]
    else
      person_id = params[:id]
    end

    settings = YAML.load_file("#{Rails.root}/config/globals.yml")[Rails.env] rescue {}

    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}

    @show_middle_name = (settings["show_middle_name"] == true ? true : false) rescue false

    @show_maiden_name = (settings["show_maiden_name"] == true ? true : false) rescue false

    @show_birthyear = (settings["show_birthyear"] == true ? true : false) rescue false

    @show_birthmonth = (settings["show_birthmonth"] == true ? true : false) rescue false

    @show_birthdate = (settings["show_birthdate"] == true ? true : false) rescue false

    @show_age = (settings["show_age"] == true ? true : false) rescue false

    @show_region_of_origin = (settings["show_region_of_origin"] == true ? true : false) rescue false

    @show_district_of_origin = (settings["show_district_of_origin"] == true ? true : false) rescue false

    @show_t_a_of_origin = (settings["show_t_a_of_origin"] == true ? true : false) rescue false

    @show_home_village = (settings["show_home_village"] == true ? true : false) rescue false

    @show_current_region = (settings["show_current_region"] == true ? true : false) rescue false

    @show_current_district = (settings["show_current_district"] == true ? true : false) rescue false

    @show_current_t_a = (settings["show_current_t_a"] == true ? true : false) rescue false

    @show_current_village = (settings["show_current_village"] == true ? true : false) rescue false

    @show_current_landmark = (settings["show_current_landmark"] == true ? true : false) rescue false

    @show_cell_phone_number = (settings["show_cell_phone_number"] == true ? true : false) rescue false

    @show_office_phone_number = (settings["show_office_phone_number"] == true ? true : false) rescue false

    @show_home_phone_number = (settings["show_home_phone_number"] == true ? true : false) rescue false

    @show_occupation = (settings["show_occupation"] == true ? true : false) rescue false

    @show_nationality = (settings["show_nationality"] == true ? true : false) rescue false

    @occupations = ['','Driver','Housewife','Messenger','Business','Farmer','Salesperson','Teacher',
                    'Student','Security guard','Domestic worker', 'Police','Office worker',
                    'Preschool child','Mechanic','Prisoner','Craftsman','Healthcare Worker','Soldier'].sort.concat(["Other","Unknown"])

    @person = Person.find(person_id)

    render :template => false
  end

  def edit_demographics

    @field = params[:field]

    if params[:id].blank?
      person_id = params[:patient_id]
    else
      person_id = params[:id]
    end
    @person = Person.find(person_id)

    @patient = @person.patient rescue nil

  end

  def update_demographics

    # raise params.inspect

    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}

    patient = Person.find(params[:person_id]).patient rescue nil

    if patient.blank?

      flash[:error] = "Sorry, patient with that ID not found! Update failed."

      redirect_to "/" and return

    end

    national_id = ((patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil) || params[:id])

    name = patient.person.names.last rescue nil

    address = patient.person.addresses.last rescue nil

    dob = (patient.person.birthdate.strftime("%Y-%m-%d") rescue nil)

    estimate = false

    if !(params[:person][:birth_month] rescue nil).blank? and (params[:person][:birth_month] rescue nil).to_s.downcase == "unknown"

      dob = "#{params[:person][:birth_year]}-07-10"

      estimate = true

    elsif !(params[:person][:birth_month] rescue nil).blank? and (params[:person][:birth_month] rescue nil).to_s.downcase != "unknown" and !(params[:person][:birth_day] rescue nil).blank? and (params[:person][:birth_day] rescue nil).to_s.downcase == "unknown"

      dob = "#{params[:person][:birth_year]}-#{"%02d" % params[:person][:birth_month].to_i}-05"

      estimate = true

    elsif !(params[:person][:birth_month] rescue nil).blank? and (params[:person][:birth_month] rescue nil).to_s.downcase != "unknown" and !(params[:person][:birth_day] rescue nil).blank? and (params[:person][:birth_day] rescue nil).to_s.downcase != "unknown" and !(params[:person][:birth_year] rescue nil).blank? and (params[:person][:birth_year] rescue nil).to_s.downcase != "unknown"

      dob = "#{params[:person][:birth_year]}-#{"%02d" % params[:person][:birth_month].to_i}-#{"%02d" % params[:person][:birth_day].to_i}"

      estimate = false

    end

    if (params[:person][:attributes]["citizenship"] == "Other" rescue false)

      params[:person][:attributes]["citizenship"] = params[:person][:attributes]["race"]
    end

    identifiers = []

    patient.patient_identifiers.each { |id|
      identifiers << {id.type.name => id.identifier} if id.type.name.downcase != "national id"
    }

    # raise identifiers.inspect

    person = {
        "national_id" => national_id,
        "application" => "#{@settings["application_name"]}",
        "site_code" => "#{@settings["site_code"]}",
        "return_path" => "http://#{request.host_with_port}/process_result",
        "patient_id" => (patient.patient_id rescue nil),
        "patient_update" => true,
        "names" =>
            {
                "family_name" => (!(params[:person][:names][:family_name] rescue nil).blank? ? (params[:person][:names][:family_name] rescue nil) : (name.family_name rescue nil)),
                "given_name" => (!(params[:person][:names][:given_name] rescue nil).blank? ? (params[:person][:names][:given_name] rescue nil) : (name.given_name rescue nil)),
                "middle_name" => (!(params[:person][:names][:middle_name] rescue nil).blank? ? (params[:person][:names][:middle_name] rescue nil) : (name.middle_name rescue nil)),
                "maiden_name" => (!(params[:person][:names][:family_name2] rescue nil).blank? ? (params[:person][:names][:family_name2] rescue nil) : (name.family_name2 rescue nil))
            },
        "gender" => (!params["gender"].blank? ? params["gender"] : (patient.person.gender rescue nil)),
        "person_attributes" => {
            "occupation" => (!(params[:person][:attributes][:occupation] rescue nil).blank? ? (params[:person][:attributes][:occupation] rescue nil) :
                (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil)),

            "cell_phone_number" => (!(params[:person][:attributes][:cell_phone_number] rescue nil).blank? ? (params[:person][:attributes][:cell_phone_number] rescue nil) :
                (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil)),

            "home_phone_number" => (!(params[:person][:attributes][:home_phone_number] rescue nil).blank? ? (params[:person][:attributes][:home_phone_number] rescue nil) :
                (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil)),

            "office_phone_number" => (!(params[:person][:attributes][:office_phone_number] rescue nil).blank? ? (params[:person][:attributes][:office_phone_number] rescue nil) :
                (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Office Phone Number").id).value rescue nil)),

            "country_of_residence" => (!(params[:person][:attributes][:country_of_residence] rescue nil).blank? ? (params[:person][:attributes][:country_of_residence] rescue nil) :
                (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Country of Residence").id).value rescue nil)),

            "citizenship" => (!(params[:person][:attributes][:citizenship] rescue nil).blank? ? (params[:person][:attributes][:citizenship] rescue nil) :
                (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil))
        },
        "birthdate" => dob,
        "patient" => {
            "identifiers" => identifiers
        },
        "birthdate_estimated" => estimate,
        "addresses" => {
            "current_residence" => (!(params[:person][:attributes][:country_of_residence] rescue nil).blank? ? (params[:person][:addresses][:address1] rescue nil) : (address.address1 rescue nil)),
            "current_village" => (!(params[:person][:attributes][:country_of_residence] rescue nil).blank? ? (params[:person][:addresses][:city_village] rescue nil) : (address.city_village rescue nil)),
            "current_ta" => (!(params[:person][:attributes][:country_of_residence] rescue nil).blank? ? (params[:person][:addresses][:township_division] rescue nil) : (address.township_division rescue nil)),
            "current_district" => (!(params[:person][:attributes][:country_of_residence] rescue nil).blank? ? (params[:person][:addresses][:state_province] rescue nil) : (address.state_province rescue nil)),
            "home_village" => (!(params[:person][:attributes][:citizenship] rescue nil).blank? ? (params[:person][:addresses][:neighborhood_cell] rescue nil) : (address.neighborhood_cell rescue nil)),
            "home_ta" => (!(params[:person][:attributes][:citizenship] rescue nil).blank? ? (params[:person][:addresses][:county_district] rescue nil) : (address.county_district rescue nil)),
            "home_district" => (!(params[:person][:attributes][:citizenship] rescue nil).blank? ? (params[:person][:addresses][:address2] rescue nil) : (address.address2 rescue nil))
        }
    }
    
    if secure?
     url = "https://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/process_confirmation"
    else
     url = "http://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/process_confirmation"
    end
    result = RestClient.post(url, {:person => person, :target => "update"})

    json = JSON.parse(result) rescue {}

    if (json["patient"]["identifiers"] rescue "").class.to_s.downcase == "hash"

      tmp = json["patient"]["identifiers"]

      json["patient"]["identifiers"] = []

      tmp.each do |key, value|

        json["patient"]["identifiers"] << {key => value}

      end

    end

    patient_id = DDE.search_and_or_create(json.to_json) # rescue nil 

    # raise patient_id.inspect

    patient = Patient.find(patient_id) rescue nil

    print_and_redirect("/patients/national_id_label?patient_id=#{patient_id}", "/dde/edit_patient/id=#{patient_id}") and return if !patient.blank? and (json["print_barcode"] rescue false)

    redirect_to "/dde/edit_patient/#{patient_id}" and return if !patient_id.blank?

    flash["error"] = "Sorry! Something went wrong. Failed to process properly!"

    redirect_to "/clinic" and return
  end

  def process_scan_data

    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}

    @json = JSON.parse(params[:person]) rescue {}

    @results = []

    if !@json.blank?
    
      if secure?
        url = "https://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/ajax_process_data"
      else
        url = "http://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/ajax_process_data"
      end
      
      @results = RestClient.post(url, {:person => @json, :page => params[:page]}, {:accept => :json})

    end

    @dontstop = false

    if JSON.parse(@results).length == 1

      result = JSON.parse(JSON.parse(@results)[0])

      checked = DDE.compare_people(result, @json) # rescue false

      if checked

        result["patient_id"] = @json["patient_id"] if !@json["patient_id"].blank?

        @results = result.to_json

        person = JSON.parse(@results) #["person"]
        
        if secure?
         url = "https://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/process_confirmation"
        else
         url = "http://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/process_confirmation"
        end 
        
        @results = RestClient.post(url, {:person => person, :target => "select"})

        @dontstop = true

      elsif !checked and @json["names"]["given_name"].blank? and @json["names"]["family_name"].blank? and @json["gender"].blank?

        # result["patient_id"] = @json["patient_id"] if !@json["patient_id"].blank?

        @results = result.to_json

        person = JSON.parse(@results) #["person"]
        
        if secure?
           url = "https://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/process_confirmation"
        else
           url = "http://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/process_confirmation"
        end
        
        @results = RestClient.post(url, {:person => person, :target => "select"})

        @dontstop = true

      else

        @results = []

        @results << result

        patient = PatientIdentifier.find_by_identifier(@json["national_id"]).patient rescue nil

        if !patient.nil?

          national_id = ((patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil) || params[:id])

          name = patient.person.names.last rescue nil

          address = patient.person.addresses.last rescue nil

          verifier = {
              "national_id" => national_id,
              "patient_id" => (patient.patient_id rescue nil),
              "names" =>
                  {
                      "family_name" => (name.family_name rescue nil),
                      "given_name" => (name.given_name rescue nil),
                      "middle_name" => (name.middle_name rescue nil),
                      "maiden_name" => (name.family_name2 rescue nil)
                  },
              "gender" => (patient.person.gender rescue nil),
              "person_attributes" => {
                  "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
                  "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
                  "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
                  "office_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Office Phone Number").id).value rescue nil),
                  "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
                  "country_of_residence" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Country of Residence").id).value rescue nil),
                  "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
              },
              "birthdate" => (patient.person.birthdate rescue nil),
              "patient" => {
                  "identifiers" => (patient.patient_identifiers.collect { |id| {id.type.name => id.identifier} if id.type.name.downcase != "national id" }.delete_if { |x| x.nil? } rescue [])
              },
              "birthdate_estimated" => ((patient.person.birthdate_estimated rescue 0).to_s.strip == '1' ? true : false),
              "addresses" => {
                  "current_residence" => (address.address1 rescue nil),
                  "current_village" => (address.city_village rescue nil),
                  "current_ta" => (address.township_division rescue nil),
                  "current_district" => (address.state_province rescue nil),
                  "home_village" => (address.neighborhood_cell rescue nil),
                  "home_ta" => (address.county_district rescue nil),
                  "home_district" => (address.address2 rescue nil)
              }
          }.to_json

          checked = DDE.compare_people(result, verifier) # rescue false

          if checked

            result["patient_id"] = @json["patient_id"] if !@json["patient_id"].blank?

            @results = result.to_json

            person = JSON.parse(@results) #["person"]
            
            if secure?
              url = "https://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/process_confirmation"
            else
              url = "http://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/process_confirmation"
            end
            
            @results = RestClient.post(url, {:person => person, :target => "select"})

            @dontstop = true

          end

        else

          @dontstop = true

        end
      end

    elsif JSON.parse(@results).length == 0

      patient = PatientIdentifier.find_by_identifier(@json["national_id"]).patient rescue nil

      if !patient.nil?
        @results = []

        national_id = ((patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil) || params[:id])

        name = patient.person.names.last rescue nil

        address = patient.person.addresses.last rescue nil

        @results << {
            "national_id" => national_id,
            "patient_id" => (patient.patient_id rescue nil),
            "names" =>
                {
                    "family_name" => (name.family_name rescue nil),
                    "given_name" => (name.given_name rescue nil),
                    "middle_name" => (name.middle_name rescue nil),
                    "maiden_name" => (name.family_name2 rescue nil)
                },
            "gender" => (patient.person.gender rescue nil),
            "person_attributes" => {
                "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
                "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
                "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
                "office_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Office Phone Number").id).value rescue nil),
                "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
                "country_of_residence" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Country of Residence").id).value rescue nil),
                "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
            },
            "birthdate" => (patient.person.birthdate rescue nil),
            "patient" => {
                "identifiers" => (patient.patient_identifiers.collect { |id| {id.type.name => id.identifier} if id.type.name.downcase != "national id" }.delete_if { |x| x.nil? } rescue [])
            },
            "birthdate_estimated" => ((patient.person.birthdate_estimated rescue 0).to_s.strip == '1' ? true : false),
            "addresses" => {
                "current_residence" => (address.address1 rescue nil),
                "current_village" => (address.city_village rescue nil),
                "current_ta" => (address.township_division rescue nil),
                "current_district" => (address.state_province rescue nil),
                "home_village" => (address.neighborhood_cell rescue nil),
                "home_ta" => (address.county_district rescue nil),
                "home_district" => (address.address2 rescue nil)
            }
        }.to_json

        @dontstop = true

      else

        redirect_to "/patient_not_found/#{(@json["national_id"] || @json["_id"])}" and return

      end

    end

    render :layout => "ts"
  end

  def ajax_process_data

    settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}

    person = JSON.parse(params[:person]) rescue {}

    result = []

    if !person.blank?
      if secure?
       url = "https://#{settings["dde_username"]}:#{settings["dde_password"]}@#{settings["dde_server"]}/ajax_process_data"
      else
       url = "http://#{settings["dde_username"]}:#{settings["dde_password"]}@#{settings["dde_server"]}/ajax_process_data"
      end
      
      results = RestClient.post(url, {:person => person, :page => params[:page]}, {:accept => :json})

      result = JSON.parse(results)

      json = JSON.parse(params[:person]) rescue {}

      patient = PatientIdentifier.find_by_identifier(json["national_id"]).patient rescue nil

      if !patient.nil?

        name = patient.person.names.last rescue nil

        address = patient.person.addresses.last rescue nil

        result << {
            "_id" => json["national_id"],
            "patient_id" => (patient.patient_id rescue nil),
            "local" => true,
            "names" =>
                {
                    "family_name" => (name.family_name rescue nil),
                    "given_name" => (name.given_name rescue nil),
                    "middle_name" => (name.middle_name rescue nil),
                    "maiden_name" => (name.family_name2 rescue nil)
                },
            "gender" => (patient.person.gender rescue nil),
            "person_attributes" => {
                "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
                "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
                "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
                "office_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Office Phone Number").id).value rescue nil),
                "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
                "country_of_residence" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Country of Residence").id).value rescue nil),
                "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
            },
            "birthdate" => (patient.person.birthdate rescue nil),
            "patient" => {
                "identifiers" => (patient.patient_identifiers.collect { |id| {id.type.name => id.identifier} if id.type.name.downcase != "national id" }.delete_if { |x| x.nil? } rescue [])
            },
            "birthdate_estimated" => ((patient.person.birthdate_estimated rescue 0).to_s.strip == '1' ? true : false),
            "addresses" => {
                "current_residence" => (address.address1 rescue nil),
                "current_village" => (address.city_village rescue nil),
                "current_ta" => (address.township_division rescue nil),
                "current_district" => (address.state_province rescue nil),
                "home_village" => (address.neighborhood_cell rescue nil),
                "home_ta" => (address.county_district rescue nil),
                "home_district" => (address.address2 rescue nil)
            }
        }.to_json

      end

      result = result.to_json

    end

    render :text => result
  end

  def process_confirmation

    @json = params[:person] rescue {}

    @results = []

    settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}

    target = params[:target]

    target = "update" if target.blank?

    if !@json.blank?
      if secure?
       url = "https://#{settings["dde_username"]}:#{settings["dde_password"]}@#{settings["dde_server"]}/process_confirmation" 
      else
       url = "http://#{settings["dde_username"]}:#{settings["dde_password"]}@#{settings["dde_server"]}/process_confirmation" 
      end
      @results = RestClient.post(url, {:person => @json, :target => target}, {:accept => :json})
    end

    render :text => @results
  end

  def patient_not_found
    @id = params[:id]

    redirect_to "/" and return if !params[:create].blank? and params[:create] == "false"
  end

  def ajax_search

    pagesize = 3

    page = (params[:page] || 1)

    offset = ((page.to_i - 1) * pagesize)

    offset = 0 if offset < 0

    result = []

    filter = {}

    settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] # rescue {}

    search_hash = {
        "names" => {
            "given_name" => (params["given_name"] rescue nil),
            "family_name" => (params["family_name"] rescue nil)
        },
        "gender" => params["gender"]
    }

    if !search_hash["names"]["given_name"].blank? and !search_hash["names"]["family_name"].blank? and !search_hash["gender"].blank? # and result.length < pagesize

      pagesize += pagesize - result.length
      if secure?
        url = "https://#{settings["dde_username"]}:#{settings["dde_password"]}@#{settings["dde_server"]}/ajax_process_data"
      else
        url = "http://#{settings["dde_username"]}:#{settings["dde_password"]}@#{settings["dde_server"]}/ajax_process_data"
      end
      remote = RestClient.post(url, {:person => search_hash, :page => page, :pagesize => pagesize}, {:accept => :json})

      json = JSON.parse(remote)

      json.each do |person|

        entry = JSON.parse(person)

        entry["application"] = "#{settings["application_name"]}"
        entry["site_code"] = "#{settings["site_code"]}"

        entry["national_id"] = entry["_id"] if entry["national_id"].blank? and !entry["_id"].blank?

        filter[entry["national_id"]] = true

        entry["age"] = (((Date.today - entry["birthdate"].to_date).to_i / 365) rescue nil)

        entry.delete("created_at") rescue nil
        entry.delete("patient_assigned") rescue nil
        entry.delete("assigned_site") rescue nil
        entry["names"].delete("family_name_code") rescue nil
        entry["names"].delete("given_name_code") rescue nil
        entry.delete("_id") rescue nil
        entry.delete("updated_at") rescue nil
        entry.delete("old_identification_number") rescue nil
        entry.delete("type") rescue nil
        entry.delete("_rev") rescue nil

        result << entry

      end

    end

    # pagesize = ((pagesize) * 2) - result.length

    Person.find(:all, :joins => [:names], :limit => pagesize, :offset => offset, :conditions => ["given_name = ? AND family_name = ? AND gender = ?", params["given_name"], params["family_name"], params["gender"]]).each do |person|

      patient = person.patient # rescue nil

      national_id = (patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil)

      next if filter[national_id]

      name = patient.person.names.last rescue nil

      address = patient.person.addresses.last rescue nil

      person = {
          "local" => true,
          "national_id" => national_id,
          "patient_id" => (patient.patient_id rescue nil),
          "age" => (((Date.today - patient.person.birthdate.to_date).to_i / 365) rescue nil),
          "names" =>
              {
                  "family_name" => (name.family_name rescue nil),
                  "given_name" => (name.given_name rescue nil),
                  "middle_name" => (name.middle_name rescue nil),
                  "maiden_name" => (name.family_name2 rescue nil)
              },
          "gender" => (patient.person.gender rescue nil),
          "person_attributes" => {
              "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
              "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
              "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
              "office_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Office Phone Number").id).value rescue nil),
              "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
              "country_of_residence" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Country of Residence").id).value rescue nil),
              "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
          },
          "birthdate" => (patient.person.birthdate rescue nil),
          "patient" => {
              "identifiers" => (patient.patient_identifiers.collect { |id| {id.type.name => id.identifier} if id.type.name.downcase != "national id" }.delete_if { |x| x.nil? } rescue [])
          },
          "birthdate_estimated" => ((patient.person.birthdate_estimated rescue 0).to_s.strip == '1' ? true : false),
          "addresses" => {
              "current_residence" => (address.address1 rescue nil),
              "current_village" => (address.city_village rescue nil),
              "current_ta" => (address.township_division rescue nil),
              "current_district" => (address.state_province rescue nil),
              "home_village" => (address.neighborhood_cell rescue nil),
              "home_ta" => (address.county_district rescue nil),
              "home_district" => (address.address2 rescue nil)
          }
      }

      person["application"] = "#{settings["application_name"]}"
      person["site_code"] = "#{settings["site_code"]}"

      result << person

      # TODO: Need to find a way to limit in a better way the number of records returned without skipping any as some will never be seen with the current approach

      # break if result.length >= 7

    end if pagesize > 0 and result.length < 8

    render :text => result.to_json
  end

  def send_to_dde

    @json = JSON.parse(params[:person]) rescue {}

    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] # rescue {}
    
    if secure?
      url = "https://#{(@settings["dde_username"])}:#{(@settings["dde_password"])}@#{(@settings["dde_server"])}/ajax_process_data" 
    else
      url = "http://#{(@settings["dde_username"])}:#{(@settings["dde_password"])}@#{(@settings["dde_server"])}/ajax_process_data" 
    end
          
    @results = RestClient.post(url, {"person" => params["person"]})

    render :layout => "ts"

  end
  
  def secure?
     @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env]
     secure = @settings["secure_connection"] rescue false
  end

  def duplicates
    render :layout => false
  end

  def search_by_name

    results = []

    people = PersonName.find(:all, :conditions => ["CONCAT(given_name, ' ', family_name) LIKE ?", "#{params["search"].strip}%"], :limit => 10) rescue []

    people.each do |person|

      record = {}

      record["patient"] = {} if record["patient"].nil?

      record["patient"]["identifiers"] = [] if record["patient"]["identifiers"].nil?

      person.person.patient.patient_identifiers.each do |ids|

        if record["National ID"].nil? and (ids.type.name.downcase == "national id" rescue false)

          record["National ID"] = ids.identifier rescue nil

        else

          record["patient"]["identifiers"] << {ids.type.name => ids.identifier} rescue nil

        end

      end rescue nil

      record["names"] = {} if record["names"].nil?

      record["names"]["Given Name"] = person.given_name rescue nil

      record["names"]["Family Name"] = person.family_name rescue nil

      record["names"]["Middle Name"] = person.middle_name rescue nil

      record["Current Residence"] = person.addresses.first.address1 rescue nil

      record["Current Village"] = person.addresses.first.city_village rescue nil

      record["Current T/A"] = identifier.patient.person.addresses.first.township_division rescue nil

      record["Current District"] = identifier.patient.person.addresses.first.state_province rescue nil

      record["Home Village"] = identifier.patient.person.addresses.first.neighborhood_cell rescue nil

      record["Home T/A"] = identifier.patient.person.addresses.first.county_district rescue nil

      record["Home District"] = identifier.patient.person.addresses.first.address2 rescue nil

      record["Gender"] = person.person.gender rescue nil

      record["Birthdate"] = person.person.birthdate rescue nil

      record["Birthdate Estimated"] = person.person.birthdate_estimated rescue nil

      attributes = ["Citizenship", "Occupation", "Home Phone Number", "Cell Phone Number", "Office Phone Number", "Race"]

      attributes.each do |a|

        record[a] = nil

      end

      person.person.person_attributes.each do |attribute|

        record[attribute.type.name] = attribute.value if attributes.include?(attribute.type.name)

      end rescue nil

      results << record

    end

    render :text => results.uniq.to_json

  end

  def search_by_id

    results = []

    identifiers = PatientIdentifier.find(:all, :conditions => ["identifier = ?", params["search"]], :limit => 10) rescue []

    identifiers.each do |identifier|

      person = identifier.patient.person.names.first

      record = {}

      record["patient"] = {} if record["patient"].nil?

      record["patient"]["identifiers"] = [] if record["patient"]["identifiers"].nil?

      identifier.patient.patient_identifiers.each do |ids|

        if record["National ID"].nil? and (ids.type.name.downcase == "national id" rescue false)

          record["National ID"] = ids.identifier rescue nil

        else

          record["patient"]["identifiers"] << {ids.type.name => ids.identifier} rescue nil

        end

      end rescue nil

      record["names"] = {} if record["names"].nil?

      record["names"]["Given Name"] = person.given_name rescue nil

      record["names"]["Family Name"] = person.family_name rescue nil

      record["names"]["Middle Name"] = person.middle_name rescue nil

      record["Current Residence"] = identifier.patient.person.addresses.first.address1 rescue nil

      record["Current Village"] = identifier.patient.person.addresses.first.city_village rescue nil

      record["Current T/A"] = identifier.patient.person.addresses.first.township_division rescue nil

      record["Current District"] = identifier.patient.person.addresses.first.state_province rescue nil

      record["Home Village"] = identifier.patient.person.addresses.first.neighborhood_cell rescue nil

      record["Home T/A"] = identifier.patient.person.addresses.first.county_district rescue nil

      record["Home District"] = identifier.patient.person.addresses.first.address2 rescue nil

      record["Gender"] = identifier.patient.person.gender rescue nil

      record["Birthdate"] = identifier.patient.person.birthdate rescue nil

      record["Birthdate Estimated"] = ((identifier.patient.person.birthdate_estimated rescue nil).to_s.strip == '1' ? true : false)

      attributes = ["Citizenship", "Occupation", "Home Phone Number", "Cell Phone Number", "Office Phone Number", "Race"]

      attributes.each do |a|

        record[a] = nil

      end

      identifier.patient.person.person_attributes.each do |attribute|

        record[attribute.type.name] = attribute.value if attributes.include?(attribute.type.name)

      end rescue nil

      results << record

    end

    render :text => results.uniq.to_json

  end

  def push_merge

    data = JSON.parse(params["data"]) rescue {}

    data["Identifiers"] = JSON.parse(data["Identifiers"]) if data["Identifiers"].class.to_s.downcase == "string"

    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] # rescue {}
    
    if secure?
      url = "https://#{(@settings["dde_username"])}:#{(@settings["dde_password"])}@#{(@settings["dde_server"])}/merge_duplicates"
    else
      url = "http://#{(@settings["dde_username"])}:#{(@settings["dde_password"])}@#{(@settings["dde_server"])}/merge_duplicates"
    end
    
    result = RestClient.post(url, {"data" => data.to_json}, {:content_type => :json}) # rescue nil

    if !result["success"].nil?

      merged = data["Identifiers"]["Merged"] rescue {}

      identifier = PatientIdentifier.find_by_identifier(merged["National ID"]) rescue nil

      identifier.patient.person.update_attributes("voided" => 1, "void_reason" => "Merged record") rescue nil

      identifier.update_attributes("voided" => 1, "void_reason" => "Merged record") rescue nil

      target = PatientIdentifier.find_by_identifier(data["Identifiers"]["National ID"]) rescue nil

      person_id = target.patient.person.person_id rescue nil

      PatientIdentifier.create("patient_id" => person_id,
                               "identifier" => merged["National ID"],
                               "identifier_type" => PatientIdentifierType.find_by_name("Old Identification Number").id) rescue nil

      merged["Identifiers"].each do |id|

        PatientIdentifier.create("patient_id" => person_id,
                                 "identifier" => id[id.keys[0]],
                                 "identifier_type" => PatientIdentifierType.find_by_name(id.keys[0]).id) rescue nil

      end

      fields = [
          "Given Name",
          "Middle Name",
          "Family Name",
          "Gender",
          "Birthdate",
          "Birthdate Estimated",
          "Current Village",
          "Current T/A",
          "Current District",
          "Home Village",
          "Home T/A",
          "Home District",
          "Occupation",
          "Home Phone Number",
          "Cell Phone Number",
          "Office Phone Number",
          "Citizenship",
          "Race"
      ]

      person = Person.find(person_id) rescue nil

      if !person.nil?

        name = PersonName.find_by_person_id(person_id) rescue nil

        name = PersonName.new if name.nil?

        addresses = PersonAddress.find_by_person_id(person_id) rescue nil

        addresses = PersonAddress.new if addresses.nil?

        fields.each do |field|

          case field
            when "Given Name"
              name.given_name = data[field]

            when "Middle Name"
              name.middle_name = data[field]

            when "Family Name"
              name.family_name = data[field]

            when "Gender"
              person.gender = data[field][0, 1] rescue nil

            when "Birthdate"
              person.birthdate = data[field]

            when "Birthdate Estimated"
              person.birthdate_estimated = data[field]

            when "Current Village"
              addresses.city_village = data[field]

            when "Current T/A"
              addresses.township_division = data[field]

            when "Current District"
              addresses.state_province = data[field]

            when "Home Village"
              addresses.neighborhood_cell = data[field]

            when "Home T/A"
              addresses.county_district = data[field]

            when "Home District"
              addresses.address2 = data[field]

            else

              if ["Occupation", "Home Phone Number", "Cell Phone Number", "Office Phone Number", "Citizenship", "Race"].include?(field)

                attribute = PersonAttribute.find_by_person_id(person_id, :conditions => ["person_attribute_type_id = ?", PersonAttributeType.find_by_name(field).id]) rescue nil

                attribute = PersonAttribute.new if attribute.nil?

                attribute.value = data[field]

                attribute.person_id = person_id

                attribute.save if !data[field].blank?

              end
          end
        end

        person.save

        name.save

        addresses.save

      end

      flash["notice"] = "Merge successful!"

    else

      flash["error"] = result["error"]

    end

    redirect_to "/dde/duplicates" and return

  end

  def display_summary

  end

  # Districts containing the string given in params[:value]
  def district
    region_id = DDERegion.find_by_name("#{params[:filter_value]}").id
    region_conditions = ["name LIKE (?) AND region_id = ? ", "#{params[:search_string]}%", region_id]

    districts = DDEDistrict.find(:all,:conditions => region_conditions, :order => 'name')
    districts = districts.map do |d|
      "<li value=\"#{d.name}\">#{d.name}</li>"
    end
    render :text => districts.join('') + "<li value='Other'>Other</li>" and return
  end

  # List traditional authority containing the string given in params[:value]
  def traditional_authority
    district_id = DDEDistrict.find_by_name("#{params[:filter_value]}").id
    traditional_authority_conditions = ["name LIKE (?) AND district_id = ?", "%#{params[:search_string]}%", district_id]

    traditional_authorities = DDETraditionalAuthority.find(:all,:conditions => traditional_authority_conditions, :order => 'name')
    traditional_authorities = traditional_authorities.map do |t_a|
      "<li value=\"#{t_a.name}\">#{t_a.name}</li>"
    end
    render :text => traditional_authorities.join('') + "<li value='Other'>Other</li>" and return
  end

  # Villages containing the string given in params[:value]
  def village
    traditional_authority_id = DDETraditionalAuthority.find_by_name("#{params[:filter_value]}").id
    village_conditions = ["name LIKE (?) AND traditional_authority_id = ?", "%#{params[:search_string]}%", traditional_authority_id]

    villages = DDEVillage.find(:all,:conditions => village_conditions, :order => 'name')
    villages = villages.map do |v|
      "<li value=\"#{v.name}\">#{v.name}</li>"
    end
    render :text => villages.join('') + "<li value='Other'>Other</li>" and return
  end

  # Landmark containing the string given in params[:value]
  def landmark

    landmarks = ["", "Market", "School", "Police", "Church", "Borehole", "Graveyard"]
    landmarks = landmarks.map do |v|
      "<li value='#{v}'>#{v}</li>"
    end
    render :text => landmarks.join('') + "<li value='Other'>Other</li>" and return
  end

  # Countries containing the string given in params[:value]
  def country
    country_conditions = ["name LIKE (?)", "%#{params[:search_string]}%"]

    countries = DDECountry.find(:all,:conditions => country_conditions, :order => 'weight')
    countries = countries.map do |v|
      "<li value=\"#{v.name}\">#{v.name}</li>"
    end
    render :text => countries.join('') + "<li value='Other'>Other</li>" and return
  end

  # Nationalities containing the string given in params[:value]
  def nationality
    nationalty_conditions = ["name LIKE (?)", "%#{params[:search_string]}%"]

    nationalities = DDENationality.find(:all,:conditions => nationalty_conditions, :order => 'weight')
    nationalities = nationalities.map do |v|
      "<li value=\"#{v.name}\">#{v.name}</li>"
    end
    render :text => nationalities.join('') + "<li value='Other'>Other</li>" and return
  end

  def family_names
    searchname("family_name", params[:search_string])
  end

  def given_names
    searchname("given_name", params[:search_string])
  end

  def family_name2
    searchname("family_name2", params[:search_string])
  end

  def middle_name
    searchname("middle_name", params[:search_string])
  end

  def searchname(field_name, search_string)
    @names = PersonNameCode.find_most_common(field_name, search_string).collect{|person_name| person_name.send(field_name)} # rescue []
    render :text => "<li>" + @names.map{|n| n } .join("</li><li>") + "</li>"
  end

end

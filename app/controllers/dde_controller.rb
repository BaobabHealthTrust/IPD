require "rest-client"

class DdeController < ApplicationController

  def index
    session[:cohort] = nil
    @facility = Location.current_health_center.name rescue ''

    @location = Location.find(session[:location_id]).name rescue ""

    @date = session[:datetime].to_date rescue Date.today.to_date

		@person = Person.find_by_person_id(current_user.person_id)

    @user = PatientService.name(@person)

    @roles = current_user.user_roles.collect{|r| r.role} rescue []

    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}
    
    render :template => 'dde/index', :layout => false
  end

  def search
    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}
    
    render :layout => false
  end

  def new
    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}
  end

  def process_result
  
    # raise params.inspect
  
    json = JSON.parse(params["person"]) rescue {}
    
    if (json["patient"]["identifiers"].class.to_s.downcase == "hash" rescue false)
      
      tmp = json["patient"]["identifiers"]
      
      json["patient"]["identifiers"] = []
      
      tmp.each do |key, value|
        
        json["patient"]["identifiers"] << {key => value}
        
      end
    
    end 
    
    patient_id = DDE.search_and_or_create(json.to_json) # rescue nil 
    
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
          "given_name" => (name.given_name rescue nil)
      },
      "gender" => (patient.person.gender rescue nil),
      "person_attributes" => {
          "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
          "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
          "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
          "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
          "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
      },
      "birthdate" => (patient.person.birthdate rescue nil),
      "patient" => {
          "identifiers" => (patient.patient_identifiers.collect{|id| {id.type.name => id.identifier} if id.type.name.downcase != "national id"}.delete_if{|x| x.nil?} rescue [])
      },
      "birthdate_estimated" => nil,
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
          "birthdateEstimated" => ((person.birthdate_estimated == 1 ? true : false) rescue false),
          "gender" => (person.gender rescue nil),
          "preferredAddress" => {
            "cityVillage" => (person.addresses.last.city_village rescue nil)
          }
        },
        "identifiers" => person.patient.patient_identifiers.collect{|id| 
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
        :identifiers => o["identifiers"].collect{|id|
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
    
    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}
            
  end

  def edit_patient
    if params[:id].blank?
      person_id = params[:patient_id]
    else
      person_id = params[:id]
    end
    
    @person = Person.find(person_id)    
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
    
    identifiers = []
    
    patient.patient_identifiers.each{|id| 
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
          "given_name" => (!(params[:person][:names][:given_name] rescue nil).blank? ? (params[:person][:names][:given_name] rescue nil) : (name.given_name rescue nil))
      },
      "gender" => (!params["gender"].blank? ? params["gender"] : (patient.person.gender rescue nil)),
      "person_attributes" => {
          "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
          "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
          "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
          "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
          "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
      },
      "birthdate" => dob,
      "patient" => {
          "identifiers" => identifiers
      },
      "birthdate_estimated" => estimate,
      "addresses" => {
          "current_residence" => (!(params[:person][:addresses][:address1] rescue nil).blank? ? (params[:person][:addresses][:address1] rescue nil) : (address.address1 rescue nil)),
          "current_village" => (!(params[:person][:addresses][:city_village] rescue nil).blank? ? (params[:person][:addresses][:city_village] rescue nil) : (address.city_village rescue nil)),
          "current_ta" => (!(params[:person][:addresses][:township_division] rescue nil).blank? ? (params[:person][:addresses][:township_division] rescue nil) : (address.township_division rescue nil)),
          "current_district" => (!(params[:person][:addresses][:state_province] rescue nil).blank? ? (params[:person][:addresses][:state_province] rescue nil) : (address.state_province rescue nil)),
          "home_village" => (!(params[:person][:addresses][:neighborhood_cell] rescue nil).blank? ? (params[:person][:addresses][:neighborhood_cell] rescue nil) : (address.neighborhood_cell rescue nil)),
          "home_ta" => (!(params[:person][:addresses][:county_district] rescue nil).blank? ? (params[:person][:addresses][:county_district] rescue nil) : (address.county_district rescue nil)),
          "home_district" => (!(params[:person][:addresses][:address2] rescue nil).blank? ? (params[:person][:addresses][:address2] rescue nil) : (address.address2 rescue nil))
      }
    }
    
    result = RestClient.post("http://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/process_confirmation", {:person => person, :target => "update"})
    
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
    
      @results = RestClient.post("http://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/ajax_process_data", {:person => @json, :page => params[:page]}, {:accept => :json})    
      
    end
    
    @dontstop = false
    
    if JSON.parse(@results).length == 1
    
      result = JSON.parse(JSON.parse(@results)[0])
      
      checked = DDE.compare_people(result, @json) # rescue false
      
      if checked    
        
        result["patient_id"] = @json["patient_id"] if !@json["patient_id"].blank?
        
        @results = result.to_json
      
        person = JSON.parse(@results)#["person"]
      
        @results = RestClient.post("http://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/process_confirmation", {:person => person, :target => "select"})
      
        @dontstop = true
        
      elsif !checked and @json["names"]["given_name"].blank? and @json["names"]["family_name"].blank? and @json["gender"].blank?
              
        # result["patient_id"] = @json["patient_id"] if !@json["patient_id"].blank?
        
        @results = result.to_json
      
        person = JSON.parse(@results)#["person"]
      
        @results = RestClient.post("http://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/process_confirmation", {:person => person, :target => "select"})
      
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
                  "given_name" => (name.given_name rescue nil)
              },
              "gender" => (patient.person.gender rescue nil),
              "person_attributes" => {
                  "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
                  "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
                  "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
                  "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
                  "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
              },
              "birthdate" => (patient.person.birthdate rescue nil),
              "patient" => {
                  "identifiers" => (patient.patient_identifiers.collect{|id| {id.type.name => id.identifier} if id.type.name.downcase != "national id"}.delete_if{|x| x.nil?} rescue [])
              },
              "birthdate_estimated" => nil,
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
          
            person = JSON.parse(@results)#["person"]
          
            @results = RestClient.post("http://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/process_confirmation", {:person => person, :target => "select"})
          
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
                "given_name" => (name.given_name rescue nil)
            },
            "gender" => (patient.person.gender rescue nil),
            "person_attributes" => {
                "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
                "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
                "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
                "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
                "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
            },
            "birthdate" => (patient.person.birthdate rescue nil),
            "patient" => {
                "identifiers" => (patient.patient_identifiers.collect{|id| {id.type.name => id.identifier} if id.type.name.downcase != "national id"}.delete_if{|x| x.nil?} rescue [])
            },
            "birthdate_estimated" => nil,
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
    
      results = RestClient.post("http://#{settings["dde_username"]}:#{settings["dde_password"]}@#{settings["dde_server"]}/ajax_process_data", {:person => person, :page => params[:page]}, {:accept => :json})   
       
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
                "given_name" => (name.given_name rescue nil)
            },
            "gender" => (patient.person.gender rescue nil),
            "person_attributes" => {
                "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
                "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
                "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
                "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
                "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
            },
            "birthdate" => (patient.person.birthdate rescue nil),
            "patient" => {
                "identifiers" => (patient.patient_identifiers.collect{|id| {id.type.name => id.identifier} if id.type.name.downcase != "national id"}.delete_if{|x| x.nil?} rescue [])
            },
            "birthdate_estimated" => nil,
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
    
    target = params[:target]
    
    target = "update" if target.blank?
    
    if !@json.blank?    
      @results = RestClient.post("http://#{settings["dde_username"]}:#{settings["dde_password"]}@#{settings["dde_server"]}/process_confirmation", {:person => person, :target => target}, {:accept => :json})    
    end
    
    render :text => @results  
  end
  
  def patient_not_found
    @id = params[:id]
    
    redirect_to "/" and return if !params[:create].blank? and params[:create] == "false"
  end
  
  def ajax_search

    pagesize = 4
    
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
    
      remote = RestClient.post("http://#{settings["dde_username"]}:#{settings["dde_password"]}@#{settings["dde_server"]}/ajax_process_data", {:person => search_hash, :page => page, :pagesize => pagesize}, {:accept => :json})    
      
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
            "given_name" => (name.given_name rescue nil)
        },
        "gender" => (patient.person.gender rescue nil),
        "person_attributes" => {
            "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
            "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
            "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
            "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
            "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
        },
        "birthdate" => (patient.person.birthdate rescue nil),
        "patient" => {
            "identifiers" => (patient.patient_identifiers.collect{|id| {id.type.name => id.identifier} if id.type.name.downcase != "national id"}.delete_if{|x| x.nil?} rescue [])
        },
        "birthdate_estimated" => nil,
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
      
    end

    render :text => result.to_json
  end
  
end

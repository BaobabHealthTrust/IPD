class PatientIdentifier < ActiveRecord::Base
  set_table_name "patient_identifier"
  set_primary_key :patient_identifier_id
  include Openmrs

  belongs_to :type, :class_name => "PatientIdentifierType", :foreign_key => :identifier_type, :conditions => {:retired => 0}
  belongs_to :patient, :class_name => "Patient", :foreign_key => :patient_id, :conditions => {:voided => 0}

  def self.calculate_checkdigit(number)
    # This is Luhn's algorithm for checksums
    # http://en.wikipedia.org/wiki/Luhn_algorithm
    # Same algorithm used by PIH (except they allow characters)
    number = number.to_s
    number = number.split(//).collect { |digit| digit.to_i }
    parity = number.length % 2

    sum = 0
    number.each_with_index do |digit,index|
      digit = digit * 2 if index%2==parity
      digit = digit - 9 if digit > 9
      sum = sum + digit
    end
    
    checkdigit = 0
    checkdigit = checkdigit +1 while ((sum+(checkdigit))%10)!=0
    return checkdigit
  end

  def self.site_prefix
    site_prefix = GlobalProperty.find_by_property("site_prefix").property_value rescue nil
    return site_prefix
  end

  def self.next_available_arv_number
    current_arv_code = self.site_prefix
    type = PatientIdentifierType.find_by_name('ARV Number').id
    current_arv_number_identifiers = PatientIdentifier.find(:all,:conditions => ["identifier_type = ? AND voided = 0",type])

    assigned_arv_ids = current_arv_number_identifiers.collect{|identifier|
      $1.to_i if identifier.identifier.match(/#{current_arv_code}-ARV- *(\d+)/)
    }.compact unless current_arv_number_identifiers.nil?

    next_available_number = nil

    if assigned_arv_ids.empty?
      next_available_number = 1
    else
      # Check for unused ARV idsV
      # Suggest the next arv_id based on unused ARV ids that are within 10 of the current_highest arv id. This makes sure that we don't get holes unless we   really want them and also means that our suggestions aren't broken by holes
      #array_of_unused_arv_ids = (1..highest_arv_id).to_a - assigned_arv_ids
      assigned_numbers = assigned_arv_ids.sort

      possible_number_range = GlobalProperty.find_by_property("arv_number_range").property_value.to_i rescue 100000
      possible_identifiers = Array.new(possible_number_range){|i|(i + 1)}
      next_available_number = ((possible_identifiers)-(assigned_numbers)).first
    end
    return "#{current_arv_code} #{next_available_number}"
  end

  def self.identifier(patient_id, patient_identifier_type_id)
    patient_identifier = self.find(:first, :select => "identifier",
                                   :conditions  =>["patient_id = ? and identifier_type = ?", patient_id, patient_identifier_type_id])
    return patient_identifier
  end

  def self.next_filing_number(type = 'Filing Number')
    available_numbers = self.find(:all,
                                  :conditions => ['identifier_type = ?',
                                  PatientIdentifierType.find_by_name(type).id]).map{ | i | i.identifier }
    
    filing_number_prefix = CoreService.get_global_property_value("filing.number.prefix") rescue "FN101,FN102" 

    prefix = filing_number_prefix.split(",")[0][0..3] if type.match(/filing/i)
    prefix = filing_number_prefix.split(",")[1][0..3] if type.match(/Archived/i)

    len_of_identifier = (filing_number_prefix.split(",")[0][-1..-1] + "00000").to_i if type.match(/filing/i)
    len_of_identifier = (filing_number_prefix.split(",")[1][-1..-1] + "00000").to_i if type.match(/Archived/i)
    possible_identifiers_range = GlobalProperty.find_by_property("filing.number.range").property_value.to_i rescue 300000
    possible_identifiers = Array.new(possible_identifiers_range){|i|prefix + (len_of_identifier + i +1).to_s}

    ((possible_identifiers)-(available_numbers.compact.uniq)).first
  end

  def after_save
    if self.identifier_type == PatientIdentifierType.find_by_name("National ID").id
      person = self.patient.person
      patient_bin = PatientService.get_patient(person)
      date_created = person.date_created.strftime('%Y-%m-%d %H:%M:%S') rescue Time.now().strftime('%Y-%m-%d %H:%M:%S')
      first_name = patient_bin.name.split(" ")[0] rescue nil
      last_name = patient_bin.name.split(" ")[1] rescue nil
      birthdate_estimated = person.birthdate_estimated

      ActiveRecord::Base.connection.execute <<EOF                             
INSERT INTO openmrs_demographx.patient (patient_id,gender,birthdate,birthdate_estimated,creator,date_created,date_changed)
VALUES(#{patient_bin.patient_id},"#{patient_bin.sex}","#{person.birthdate}",#{birthdate_estimated},#{person.creator},'#{date_created}','#{date_created}');
EOF

      ActiveRecord::Base.connection.execute <<EOF                             
INSERT INTO openmrs_demographx.patient_name (patient_id,given_name,family_name,creator,date_created,date_changed)
VALUES(#{patient_bin.patient_id},"#{first_name}","#{last_name}",#{person.creator},'#{date_created}','#{date_created}');
EOF

      ActiveRecord::Base.connection.execute <<EOF                             
INSERT INTO openmrs_demographx.patient_identifier (patient_id,identifier,identifier_type,creator,date_created)
VALUES(#{patient_bin.patient_id},"#{patient_bin.national_id}",1,#{person.creator},'#{date_created}');
EOF
    end rescue nil 
  end

end

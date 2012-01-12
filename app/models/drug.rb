class Drug < ActiveRecord::Base
  set_table_name :drug
  set_primary_key :drug_id
  include Openmrs
  belongs_to :concept, :conditions => {:retired => 0}
  belongs_to :form, :foreign_key => 'dosage_form', :class_name => 'Concept', :conditions => {:retired => 0}

end

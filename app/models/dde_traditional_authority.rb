class DDETraditionalAuthority < ActiveRecord::Base
    set_table_name  "dde_traditional_authority"
    set_primary_key "traditional_authority_id"

	belongs_to :district

end

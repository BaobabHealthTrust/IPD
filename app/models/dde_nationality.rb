class DDENationality < ActiveRecord::Base
	set_table_name "dde_nationality"
	set_primary_key "nationality_id"

	belongs_to :region

end

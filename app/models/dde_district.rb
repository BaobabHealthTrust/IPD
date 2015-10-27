class DDEDistrict < ActiveRecord::Base
	set_table_name "dde_district"
	set_primary_key "district_id"

	belongs_to :region

end

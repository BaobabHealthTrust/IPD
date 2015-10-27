class DDECountry < ActiveRecord::Base
	set_table_name "dde_country"
	set_primary_key "country_id"

	belongs_to :region

end

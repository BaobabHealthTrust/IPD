class DDEVillage < ActiveRecord::Base
	set_table_name "dde_village"
	set_primary_key "village_id"

	belongs_to :traditional_authority

end

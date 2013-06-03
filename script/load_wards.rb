
  def load_wards
    ActiveRecord::Base.connection.execute <<EOF
      DROP TABLE IF EXISTS `ward`;
EOF

    ActiveRecord::Base.connection.execute <<EOF
      CREATE TABLE `ward` (                                                
        `ward_id` int(11) NOT NULL AUTO_INCREMENT,
        `name` varchar(45) NOT NULL,                                             
        `bed_number` int(11),                                                
        PRIMARY KEY (`ward_id`),
        UNIQUE KEY `id_UNIQUE` (`ward_id`)
      ) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=latin1; 
EOF

    kch_wards = CoreService.get_global_property_value('kch_wards').split(',').compact
    kch_wards.each do |kch_ward|
      ward = Ward.new()
      ward.name = kch_ward.squish
      ward.save
      puts "................. Successfully added : #{kch_ward}"
    end
  end

  load_wards


  def load_wards
    ActiveRecord::Base.connection.execute <<EOF
      DROP TABLE IF EXISTS `ward`; 
EOF
	ActiveRecord::Base.connection.execute <<EOF
		  DROP TABLE IF EXISTS `team`; 
EOF
    ActiveRecord::Base.connection.execute <<EOF
      CREATE TABLE `ward` (                                                
        `ward_id` int(11) NOT NULL AUTO_INCREMENT,
        `name` varchar(45) NOT NULL,                                             
        `bed_number` int(11),
        `voided` smallint(6) NOT NULL DEFAULT '0',
        `voided_by` int(11) DEFAULT NULL,
        `date_voided` datetime DEFAULT NULL,
        PRIMARY KEY (`ward_id`),
        UNIQUE KEY `id_UNIQUE` (`ward_id`),
        UNIQUE KEY `name_UNIQUE` (`name`)
      ) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=latin1; 
            
EOF
ActiveRecord::Base.connection.execute <<EOF
      CREATE TABLE `team` (                                                
        `team_id` int(11) NOT NULL AUTO_INCREMENT,
        `name` varchar(45) NOT NULL,                                             
        PRIMARY KEY (`team_id`),
        UNIQUE KEY `id_UNIQUE` (`team_id`),
        UNIQUE KEY `name_UNIQUE` (`name`)
      ) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=latin1; 
EOF

    kch_wards = CoreService.get_global_property_value('kch_wards').split(',').compact
    kch_wards.each do |kch_ward|
      ward = Ward.new()
      ward.name = kch_ward.squish.gsub("_",' ')
      ward.save
      puts "................. Successfully added : #{ ward.name}"
    end
    puts ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    team = Team.new
    team.name = "Team A"
    team.save
    puts "Added default team: #{team.name}"
  end

  load_wards

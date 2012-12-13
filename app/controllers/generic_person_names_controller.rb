class GenericPersonNamesController < ApplicationController
  def family_names
    search("family_name", params[:search_string])
  end

  def given_names
    search("given_name", params[:search_string])
  end

  def family_name2
    search("family_name2", params[:search_string])
  end

  def middle_name
    search("middle_name", params[:search_string])
  end

  def search(field_name, search_string)
    if search_string.blank?
      names = PersonNameCode.find_top_ten(field_name).collect{|person_name| person_name.send(field_name)}
    else
      names = PersonNameCode.find_most_common(field_name, search_string).collect{|person_name| person_name.send(field_name)}
    end
    result = "<li>" + names.map{|n| n } .join("</li><li>") + "</li>"
    render :text => result
  end

  def ta
    search_ta("name", params[:search_string])
  end

  def village
    search_village("name", params[:search_string])
  end

  def district
    search_district("name", params[:search_string])
  end

  def search(field_name, search_string)
    if search_string.blank?
      names = PersonNameCode.find_top_ten(field_name).collect{|person_name| person_name.send(field_name)}
    else
      names = PersonNameCode.find_most_common(field_name, search_string).collect{|person_name| person_name.send(field_name)}
    end
    result = "<li>" + names.map{|n| n } .join("</li><li>") + "</li>"
    render :text => result
  end

  def search_ta(field_name, search_string)
    if search_string.blank?
      traditional_authorities = TraditionalAuthority.find(:all, :limit => 10).collect{|ta| ta.send(field_name)}
    else
      traditional_authorities = TraditionalAuthority.find(:all, :limit => 10, :conditions => ["#{ search_string} LIKE ?", search_string ]).collect{|ta|ta.send(field_name)}
    end
    result = "<li>" + traditional_authorities.map{|n| n } .join("</li><li>") + "</li>"
    render :text => result
  end

  def search_district(field_name, search_string)
    if search_string.blank?
      districts = District.find(:all, :limit => 10).collect{|district| district.send(field_name)}.uniq
    else
      districts = District.find(:all, :limit => 10, :conditions => ["#{field_name} LIKE ?", "#{search_string}%" ]).collect{|district|district.send(field_name)}.uniq
    end
    result = "<li>" + districts.map{|n| n } .join("</li><li>") + "</li>"
    render :text => result
  end
  def search_ta(field_name, search_string)
    if search_string.blank?
      traditional_authorities = TraditionalAuthority.find(:all, :limit => 10).collect{|ta| ta.send(field_name)}.uniq
    else
      traditional_authorities = TraditionalAuthority.find(:all, :limit => 10, :conditions => ["#{field_name} LIKE ?", "#{search_string}%" ]).collect{|ta|ta.send(field_name)}.uniq
    end
    result = "<li>" + traditional_authorities.map{|n| n } .join("</li><li>") + "</li>"
    render :text => result
  end

  def search_village(field_name, search_string)
    if search_string.blank?
      villages = Village.find(:all, :limit => 10).collect{|ta| ta.send(field_name)}
    else
      villages = Village.find(:all, :limit => 10, :conditions => ["#{field_name} LIKE ?", "#{search_string}%" ]).collect{|village|village.send(field_name)}.uniq
    end
    result = "<li>" + villages.map{|n| n } .join("</li><li>") + "</li>"
    render :text => result
  end

  def edit
    if request.get?
      @patient = Patient.find(params[:id])
      @patient_or_guardian = "patient"
      @given_name = @patient.person.names.first.given_name
      @family_name = @patient.person.names.first.family_name
      render :layout => true
    elsif request.post? && params[:given_name] && params[:family_name]
      patient = Patient.find(params[:id])
      patient.person.names.each{|patient_name|patient_name.void('given another name')}

	    person_name = PersonName.new
	    person_name.given_name = params[:given_name]
	    person_name.family_name = params[:family_name]
	    person_name.person = patient.person
	    person_name.save
      redirect_to :controller => :patients, :action => :edit_demographics, :id => patient.id
    end
  end
end

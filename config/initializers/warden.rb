# Setup Session Serialization
class Warden::SessionSerializer
  def serialize(user)
    user.user_id
  end

  def deserialize(key)
    User.find(key)
  end
end

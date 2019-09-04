class Protobuf::House(T)
  META_JOB_GROUP = "job_group"
  META_JOB_VALUE = "job_value"

  def checkin(value : String?)
    meta({
      META_JOB_VALUE => value,
    })
  end

  def checkin(value : String?, group : String)
    meta({
      META_JOB_GROUP => group,
      META_JOB_VALUE => value,
    })
  end

  def checkout : String?
    value = meta[META_JOB_VALUE]?
    meta({
      META_JOB_GROUP => nil,
      META_JOB_VALUE => nil,
    })
    return value
  end  

  def resume? : String?
    return meta[META_JOB_VALUE]?
  end

  def resume?(group : String) : String?
    value = meta[META_JOB_VALUE]?
    if value && (group == meta[META_JOB_GROUP]?)
      return value
    else
      return nil
    end
  end
end

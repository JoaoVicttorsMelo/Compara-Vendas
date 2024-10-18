require 'active_record'
class FiliaisIp < ActiveRecord::Base
  self.table_name = "filiais_ip"
end

class UltimoEmail < ActiveRecord::Base
  self.table_name = "ultimo_email"
end

pry -r ./fritz_client.rb

@box = FritzClient.new("fritz.box", "secure_password")

@box.change_settings({"telcfg:settings/Diversity0/Active" => 0})

@box.change_settings({"telcfg:settings/Diversity0/Active" => 0, "telcfg:settings/Diversity1/Active" => 1})

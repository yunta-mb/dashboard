require 'faye'
bayeux = Faye::RackAdapter.new(:mount => '/live', :timeout => 25)
run bayeux


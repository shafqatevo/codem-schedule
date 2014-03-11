module Jobs
  module States
    def self.included(base)
      base.class_eval do
        after_initialize :set_initial_state
      end
    end
    
    def initial_state
      Job::Scheduled
    end
    
    def enter(new_state, params={}, headers={})
      old_state  = self.state
      self.state = new_state

      notified_at = find_notified_at(headers)

      if new_state != old_state || state_changes.empty?
        self.state_changes.create(:state => new_state, 
                                  :message => params['message'], 
                                  :notified_at => notified_at)
      end
      
      last_notified_at = state_changes.last.notified_at

      if last_notified_at.blank? || notified_at >= last_notified_at
        self.send("enter_#{new_state}", params)
        save
      end

      self
    end
    
    protected
      def find_notified_at(headers)
        timestamp = headers['HTTP_X_CODEM_NOTIFY_TIMESTAMP'].to_i

        if timestamp == 0
          Time.now.to_f
        else
          timestamp / 1000.0
        end
      end

      def set_initial_state
        self.state ||= Job::Scheduled
      end

      def enter_scheduled(params)
      end

      def enter_accepted(params)
        update_attributes :host_id => params['host_id'],
                          :remote_job_id => params['job_id'],
                          :transcoding_started_at => Time.current
      end
      
      def enter_processing(params)
        update_attributes :progress => params['progress'],
                          :duration => params['duration'],
                          :filesize => params['filesize']
        notify
      end
      
      def enter_on_hold(params)
      end
      
      def enter_failed(params)
        update_attributes :message => params['message']
        notify
      end
      
      def enter_success(params)
        update_attributes :completed_at => Time.current,
                          :message => params['message'],
                          :progress => 1.0
        notify
      end
      
      def notify
        notifications.each { |n| n.notify!(:job => self, :state => state) }
      end
  end
end

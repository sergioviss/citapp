class DashboardController < ApplicationController
  def index
    render layout: "default", :template => 'index'
  end
  def analytics
    render layout: "default", :template => 'analytics'
  end
  def finance
    render layout: "default", :template => 'finance'
  end
  def crypto
    render layout: "default", :template => 'crypto'
  end
end

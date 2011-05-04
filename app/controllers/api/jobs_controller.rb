class Api::JobsController < ApplicationController
  respond_to :json, :xml
  
  def create
    job = Job.from_api(params)
    job.save
    respond_with job, :location => api_job_url(job)
  end
  
  def show
    job = Job.find(params[:id])
    respond_with job
  end
end

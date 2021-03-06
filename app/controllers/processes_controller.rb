#
#--
# Copyright (c) 2008, John Mettraux, OpenWFE.org
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# . Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# . Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# . Neither the name of the "OpenWFE" nor the names of its contributors may be
#   used to endorse or promote products derived from this software without
#   specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#++
#

require 'openwfe/representations'


class ProcessesController < ApplicationController

  before_filter :login_required

  # GET /processes
  #
  def index

    @processes = ruote_engine.process_statuses

    respond_to do |format|

      format.html # => app/views/processes.html.erb

      format.json do
        render(:json => OpenWFE::Json.processes_to_h(
          @processes, :linkgen => LinkGenerator.new(request)).to_json)
      end

      format.xml do
        render(
          :xml => OpenWFE::Xml.processes_to_xml(
            @processes, :linkgen => LinkGenerator.new(request), :indent => 2))
      end
    end
  end

  # GET /processes/1
  #
  def show

    @process = ruote_engine.process_status(params[:id])

    respond_to do |format|

      format.html # => app/views/show.html.erb

      format.json do
        render(:json => OpenWFE::Json.process_to_h(
          @process, :linkgen => LinkGenerator.new(request)).to_json)
      end

      format.xml do
        render(
          :xml => OpenWFE::Xml.process_to_xml(
            @process, :linkgen => LinkGenerator.new(request), :indent => 2))
      end
    end
  end

  # GET /processes/:wfid/edit
  #
  def edit

    @process = ruote_engine.process_status(params[:id])

    # only replying in HTML ...
  end

  def tree

    process = ruote_engine.process_status(params[:id])
    var = params[:var] || 'proc_tree'

    # TODO : use Rails callback

    render(
      :text => "var #{var} = #{process.current_tree.to_json};",
      :content_type => 'text/javascript')
  end

  # GET /processes/new
  #
  def new

    @definition = Definition.find(params[:definition])
  end

  # POST /processes
  #
  def create

    li = parse_launchitem

    return error_reply('no suitable launchitem found') unless li

    options = {
      :variables => { 'launcher' => current_user.login }
    }

    fei = ruote_engine.launch(li, options)

    sleep 0.200

    flash[:notice] = "launched process instance #{fei.wfid}"

    headers['Location'] = process_url(fei.wfid)

    respond_to do |format|

      format.html {
        redirect_to :action => 'show', :id => fei.wfid }
      format.json {
        render :json => "{\"wfid\":#{fei.wfid}}", :status => 201 }
      format.xml {
        render :xml => "<wfid>#{fei.wfid}</wfid>", :status => 201 }
    end
  end

  # DELETE /processes/1
  #
  def destroy

    RuotePlugin.ruote_engine.cancel_process(params[:id])

    sleep 0.200

    redirect_to :controller => :processes, :action => :index
  end

  protected

    def authorized? (action=action_name, resource=nil)

      return false unless current_user

      return true if %w{ show index }.include?(action)

      current_user.is_admin?
    end

    def parse_launchitem

      begin

        ct = request.content_type.to_s

        # TODO : deal with Atom[Pub]

        return OpenWFE::Xml::launchitem_from_xml(request.body.read) \
          if ct.match(/xml$/)

        return OpenWFE::Json.launchitem_from_json(request.body.read) \
          if ct.match(/json$/)

        #
        # then we have a form...

        if definition_id = params[:definition_id]
          definition = Definition.find(definition_id)
          params[:definition_url] = definition.local_uri if definition
        end

        if attributes = params[:attributes]
          params[:attributes] = ActiveSupport::JSON::decode(attributes)
        end

        OpenWFE::LaunchItem.from_h(params)

      rescue Exception => e

        logger.warn "failed to parse launchitem : #{e}"

        nil
      end
    end
end


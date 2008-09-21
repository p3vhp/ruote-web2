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

  #
  # GET /processes
  #
  def index

    @processes = ruote_engine.list_process_status

    respond_to do |format|

      format.html # => app/views/processes.html.erb

      format.json do
        render :json => @processes.values.to_json
      end

      format.xml do
        render(
          :xml => OpenWFE::Xml::processes_to_xml(
            @processes, :request => request, :indent => 2))
      end
    end
  end

  def show
  end

  #
  # POST /processes
  #
  def create

    li = parse_launchitem

    return error_reply('no suitable launchitem found') unless li

    fei = ruote_engine.launch(li)

    flash[:notice] = "launched process instance #{fei.wfid}"

    # TODO : html : redirect to a 'home' page

    headers['Location'] = process_url(fei.wfid)

    respond_to do |format|

      format.html { redirect_to "/processes/#{fei.wfid}" }
      format.json { render :json => "{\"wfid\":#{fei.wfid}}", :status => 201 }
      format.xml { render :xml => "<wfid>#{fei.wfid}</wfid>", :status => 201 }
    end
  end

  protected

    def parse_launchitem

      ct = request.content_type.to_s

      return OpenWFE::Xml::launchitem_from_xml(request.body.read) \
        if ct == 'application/xml'

      return OpenWFE::Json.launchitem_from_json(request.body.read) \
        if ct == 'application/json'

      OpenWFE::LaunchItem.from_h(params)

      rescue Exception => e

        logger.warn "failed to parse launchitem : #{e}"

        nil
    end
end


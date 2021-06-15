<script>

/**
 *    Copyright (C) 2021 Daniel Dowse <dev@daemonbytes.net>
 *
 *    All rights reserved.
 *
 *    Redistribution and use in source and binary forms, with or without
 *    modification, are permitted provided that the following conditions are met:
 *
 *    1. Redistributions of source code must retain the above copyright notice,
 *       this list of conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *
 *    THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 *    INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 *    AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 *    AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 *    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *    POSSIBILITY OF SUCH DAMAGE.
 *
 */

    $( document ).ready(function() {
        $("#grid-clients").UIBootgrid(
            {   search:'/api/multihop/settings/searchItem/',
                get:'/api/multihop/settings/getActiveClients/',
                set:'/api/multihop/settings/setItem/',
                add:'/api/multihop/settings/addItem/',
                del:'/api/multihop/settings/delItem/',
                toggle:'/api/multihop/settings/toggleItem/'
            }
        );

        //  Get active opnvpn clients and create a select list
        ajaxGet('/api/multihop/settings/getActiveClients/', {}, function(data, status){
            $.each(data, function (idx, record) {
                var client_vpnid=$("<option/>").val(record.vpnid).text(record.description);
                client_vpnid.data('presets', record);
                $("#client\\.vpnid").append(client_vpnid);
            });

            // Initial set of "client.description" field
            var opt = $("#client\\.vpnid").find('option:selected').text();
            $('tr[id="row_client.description"]').addClass('hidden');
            $("#client\\.description").val(opt);
            $("#client\\.vpnid").selectpicker('refresh');
        });

        // Change the value of "client.description" to new on change of option
        $(document).on('change', 'select', function() {
            var opt = $(this).find('option:selected').text();
            $("#client\\.description").val(opt);
        });


        $("#reconfigureAct").SimpleActionButton({
            onPreAction: function() {
                const dfObj = new $.Deferred();
                saveFormToEndpoint("/api/multihop/settings/set", 'frm_general_settings', function(){
                    dfObj.resolve();
                });
                return dfObj;
            }
        });

        updateServiceControlUI('multihop');

        let data_get_map = {'frm_general_settings':"/api/multihop/settings/get"};
        mapDataToFormUI(data_get_map).done(function(data){
            formatTokenizersUI();
            $('.selectpicker').selectpicker('refresh');
        });
    });

</script>

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#general">{{ lang._('General') }}</a></li>
    <li><a data-toggle="tab" href="#clients">{{ lang._('Clients') }}</a></li>
</ul>

<div class="tab-content content-box tab-content">
    <div id="general" class="tab-pane fade in active">
        <div class="content-box" style="padding-bottom: 1.5em;">
            {{ partial("layout_partials/base_form",['fields':generalForm,'id':'frm_general_settings'])}}
            <div class="col-md-12">
                <div id="multihopChangeMessage" class="alert alert-info" style="display: none" role="alert">
                    {{ lang._('After changing settings, please remember to apply them with the button below') }}
                </div>
                <hr/>
                <button class="btn btn-primary" id="reconfigureAct"
                                                data-endpoint='/api/multihop/service/reconfigure'
                                                data-label="{{ lang._('Apply') }}"
                                                data-service-widget="multihop"
                                                data-error-title="{{ lang._('Error reconfiguring multihop') }}"
                                                type="button"
                                                ></button>
                <br/><br/>
            </div>
        </div>
    </div>
    <div id="clients" class="tab-pane fade-in">
        <table id="grid-clients" class="table table-condensed table-hover table-striped" data-editDialog="dialogClients">
            <thead>
                <tr>
                    <th data-column-id="vpnid" data-type="string" data-identifier="true" data-visible="false">{{ lang._('ID') }}</th>
                    <th data-column-id="description" data-type="string">{{ lang._('Description') }}</th>
                    <th data-column-id="commands" data-width="7em" " data-formatter="commands" data-sortable="false">{{ lang._('Commands') }}</th>
                </tr>
            </thead>
            <tbody>
            </tbody>
            <tfoot>
                <tr>
                    <td></td>
                    <td>
                        <button data-action="add" type="button" class="btn btn-xs btn-default"><span class="fa fa-plus"></span></button>
                        <button data-action="deleteSelected" type="button" class="btn btn-xs btn-default"><span class="fa fa-trash-o"></span></button>
                    </td>
                </tr>
            </tfoot>
        </table>
    </div>
</div>

{{ partial("layout_partials/base_dialog",['fields':formdialogClients,'id':'dialogClients','label':lang._('Add Client')]) }}

<script>
    $( document ).ready(function() {
        $("#grid-clients").UIBootgrid(
            {   search:'/api/multihop/settings/searchItem/',
                get:'/api/multihop/settings/get/',
                set:'/api/multihop/settings/setItem/',
                add:'/api/multihop/settings/addItem/',
                del:'/api/multihop/settings/delItem/',
                toggle:'/api/multihop/settings/toggleItem/'
            }
        );

        //  Get active opnvpn clients and create a select list
        ajaxGet('/api/multihop/client/getActive/', {}, function(data, status){
            $.each(data, function (idx, record) {
                var client_vpnid=$("<option/>").val(record.vpnid).text(record.description);
                client_vpnid.data('presets', record);
                $("#client\\.vpnid").append(client_vpnid);
            });

            // Initial set of "client.description" field 
            var opt = $("#client\\.vpnid").find('option:selected').text(); 
            $("#client\\.description").val(opt);
            $("#client\\.vpnid").selectpicker('refresh');
        });

        // Change the value of "client.description" to new on change of option
        $(document).on('change', 'select', function() {
            var opt = $(this).find('option:selected').text(); 
            $("#client\\.description").val(opt);
        });


        $(function() {
            var data_get_map = {'frm_general_settings':"/api/multihop/general/get"};
            mapDataToFormUI(data_get_map).done(function(data){
                formatTokenizersUI();
                $('.selectpicker').selectpicker('refresh');
            });

            updateServiceControlUI('multihop');

            $("#saveAct").click(function(){
                saveFormToEndpoint(url="/api/multihop/general/set", formid='frm_general_settings',callback_ok=function()
                    {
                        $("#saveAct_progress").addClass("fa fa-spinner fa-pulse");
                        ajaxCall(url="/api/multihop/service/reconfigure", sendData={}, callback=function(data,status) 
                            {
                            updateServiceControlUI('multihop');
                            $("#saveAct_progress").removeClass("fa fa-spinner fa-pulse");
                        });
                    });
            });
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
                <hr />
                <button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b> <i id="saveAct_progress"></i></button>
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

<?php
namespace OPNsense\Multihop;
class IndexController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->generalForm = $this->getForm("general");
        // this is what is shown in add dialog:
        $this->view->formdialogClients = $this->getForm("dialogClients");
        $this->view->pick('OPNsense/Multihop/index');
    }
}

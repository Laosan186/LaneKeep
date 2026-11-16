'require lanekeep.foundation as foundation';
'require lanekeep.i18n as lk';
'use strict';
'require view';
'require lanekeep-home as home';
return foundation.view(view,{
 load: function() { return home.read('24h','none','').catch(function() { return null; }); },
 render: function(data) { return home.render(data); },
 handleSave: null, handleSaveApply: null, handleReset: null
});

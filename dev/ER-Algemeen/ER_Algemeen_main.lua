--%%name:ER-Algemeen
--%%type:com.fibaro.deviceController
--%%property:useUiView=true
--%%property:typeTemplateInitialized=true
--%%property:userDescription=
--%%u:{label='info',text='EventRunnner 7'}
--%%u:{button='refresh',text='🔄 Rules',onReleased='refreshRules'}
--%%u:{label='status',text='Loading rules...'}
--%%file:ER_Algemeen_tokenizer.lua,tokenizer
--%%file:ER_Algemeen_parser.lua,parser
--%%file:ER_Algemeen_csp.lua,csp
--%%file:ER_Algemeen_utils.lua,utils
--%%file:ER_Algemeen_props.lua,props
--%%file:ER_Algemeen_compiler.lua,compiler
--%%file:ER_Algemeen_scriptfuns.lua,scriptfuns
--%%file:ER_Algemeen_rule.lua,rule
--%%file:ER_Algemeen_templates.lua,templates
--%%file:ER_Algemeen_stdfuns.lua,stdfuns
--%%fqafiles:true
-- --------------- EOH ---------------
------------------------ Algemeen --------
--%%name:EventRunner7
--%%type:com.fibaro.deviceController
--%%include:EventRunner.inc
--%%file:src/Setup.lua,stdfuns
--%%u:{label='info', text='EventRunnner 7'}
--%%u:{button='refresh', text='🔄 Rules', onReleased='refreshRules'}
--%%u:{label='status', text='Loading rules...'}

-- The UI handler (QuickApp:refreshRules) and the auto-refresh hook live in
-- src/Rule.lua, so the QA Updater can ship them; only the %%u rows stay
-- here (flua and the HC3 read UI directives from the main file's header).
------------- ads ----------------

api.post("/globalVariables", {name="HomeTable", value="{}"})
local function main(er)
  local rule,var = er.eval,er.variables
  er.opts = { started = true, check = true, result = true, triggers=true}

  rule("@@00:00:05 => log[({'red','green','yellow'})[rnd(1,3)]]('tick!')",{check=false})

  local triggerVar = er.triggerVars

  print("HT:",fibaro.getGlobalVariable("HomeTable"))

  local HT = json.decode((fibaro.getGlobalVariable("HomeTable")))
  for k,v in pairs(HT) do var[k]=v end
-------------
--[[
er.addStdProp('fadeTo',{
   set =    function(_,id,val) fibaro.call(id,"fadeTo",table.unpack(val)) end
})
er.addStdProp('setDim',{
   set = function(_,id,val) fibaro.call(id,"setDim",val) end
})
]]

rule("post(#ER7_started,nextDST())")     -- post event at next daylight savings time
rule("#ER7_started => plugin['restart']()") -- Restart QA when DST hour jumps.

  ---------einde adds--------------------


------------------------------------------------------
 rule("log.skyblue('01-DEFTRIGGER')")
-------------------------------------------------------

  triggerVar.schakelaar_lezen_kunst = false
  triggerVar.schakelaar_salon_tv = false


  triggerVar.test1 = false
  triggerVar.test3 = false
  triggerVar.test5 = false
  triggerVar.test8 = false
  triggerVar.test10 = false
  triggerVar.test11 = false


  rule("wait(00:00:01) ; test1 = true") 
  rule("wait(00:00:03) ; test3 = true")   
  rule("wait(00:00:05) ; test5 = true")   
  rule("wait(00:00:08) ; test8 = true")  
  rule("wait(00:00:10) ; test10 = true")  
  rule("wait(00:00:10) ; test11 = true")  
rule("test1=>log.orchid('test1 is waar vandaar >>>>>>> true')")
rule("test3=>log.orchid('test3 is waar vandaar >>>>>>> true')")
rule("test5=>log.orchid('test5 is waar vandaar >>>>>>> true')")
rule("test8=>log.orchid('test8 is waar vandaar >>>>>>> true')")
rule("test10=>log.orchid('test10 is waar vandaar >>>>>>> true')")
rule("test11=>log.orchid('test11 is waar vandaar >>>>>>> true')")

----------------------------------------------------------
 rule("log.skyblue('02-QA PUSH & TELEGRAMBERICHTEN')")
----------------------------------------------------------

 rule("user={2,20,23}") -- ID of the user that will get the messages

--03:05..02:55 & 
 rule([[test1 =>
    fibaro.alert('push', user, 'Let Op QA 57 >>> is opnieuw gestart');
    fibaro.call(35, "sendMessage", "Let Op QA 57 >>> is opnieuw gestart",817111904);
        log.yellow('🔴🟠🟡🟢🔵🟣Let Op QA 57 >>> is opnieuw gestart 🔴🟠🟡🟢🔵🟣');
        log('02-A');
    wait(0)
]])


--hub.call('580,'Push',json.encode({'Jachtlaan:','1','pushover','kippenhoklicht aan!'}')
--hub.alert('push', {2, 23, }, 'test push3 msg', false,')

---------------------------------------------------
rule("log.skyblue('03-PROBEERSEL')")  
---------------------------------------------------
--locatie
rule("global('Locatie_Sjaak')") --; log.pink('Aangemaakt GV $Locatie_Sjaak >>> %s',$Locatie_Sjaak)")
rule("global('Locatie_Arleta')") 
rule("global('Locatie_Bewoners')") 
---------------------------------------------------
rule("log.skyblue('04-INTERNET reset')") 
--------------------------------------------------

--& wnum % 4 == 0

 rule([[@12:15 & month('jan-dec') & wday('fri')  =>
       log.yellow('08-C - Restart modem en routers');
       fibaro.call(35, "sendMessage", "Restart modem en routers na 1 minuut",817111904);
            keuken.hue_Bridge:off;
        log.yellow('04-A - keuken.hue_Bridge - Uit');
            log.green('04-A - Modem & routers >>>>>>>> restart!!!!!!!!!!!!');
wait(0)
]])

---------------------------------------------------
rule("log.skyblue('05-HUE BRIDGE AAN_UIT')") 
---------------------------------------------------

rule([[trueFor(00:00:10, keuken.hue_Bridge:isOff) =>
    keuken.hue_Bridge:on;
        log.yellow('05-A - Na 30sec uit automatisch >>> keuken.hue_Bridge - Aan');
wait(0)
]])
    

rule([[keuken.hue_Bridge:isOn | keuken.hue_Bridge:isOff =>case
    || keuken.hue_Bridge:isOn >>
        log.yellow('05-2C - keuken.hue_Bridge - Aan');
wait(0)
    || keuken.hue_Bridge:isOff >>
        log.yellow('05-4C - keuken.hue_Bridge - Uit');
wait(0)
end
]])

---------------------------------------------------
rule("log.skyblue('06-RESTART ROUTERS')")  
---------------------------------------------------


rule([[@12:45 & month('jan-dec') & wday('sun') =>
    keuken.router_Main:off;
    utility.router_Slave:off;
        log('#C:gray#06-E - keuken.router_Main - Uit');
        log('#C:gray#06-E - utility.router_Slave - Uit');
    wait(0)
    ]])

rule([[trueFor(00:00:15, keuken.router_Main:isOff) =>
    keuken.router_Main:on;
        log('#C:gray#06-G - keuken.router_Main - Aan');
    wait(0)
]])

    rule([[trueFor(00:00:15, utility.router_Slave:isOff) =>
        utility.router_Slave:on;
        log('#C:gray#06-I - utility.router_Slave - Aan');
    wait(0)
    ]])

---------------------------------------------------
rule("log.skyblue('06-RESTART HC3')")  
---------------------------------------------------

     rule([[@@01:00 | test3 => 
    $Systeem_Uptime = (os.time() - api.get('/settings/info').serverStatus)/3600;
        log('#C:gray#HC3 uptime %.0f hours',(os.time() - api.get('/settings/info').serverStatus)/3600);
        ram=api.get('/diagnostics').memory.used;
        $Systeem_Geheugengebruik = ram;
        log('#C:gray#$Systeem_Geheugengebruik %s%%',ram);
        log('06-A');
wait(0)
]])
--Clear History 958
--QA-AA.Restart HC3 of 188
 rule([[#HC3_restart =>
    958:start;
    wait(00:00:10);
     fibaro.scene("execute", {188})
        log('#C:gray#03-C - Historie leegmaken');
        log('#C:gray#03-C - Systeem RESTART');
wait(0)
]])

--[[rule([[test5 => 
        _creds = fibaro.basicAuthorization('sjaak@koppejan.org','Leerde75Lopen@');
        log('#C:red#Restart HC3');
        hc3api.post('/service/reboot',{recovery=false})
    ]]


--[[local http = net.HTTPClient({ timeout = 2000 })
http:request("http://192.168.50.10/api/settings/reboot", {
    options = {
        method = "POST",
        headers = {
            ["Authorization"] = auth,
            ["Content-Type"] = "application/json"
        }
    },
--]]
--LET OP IN SCENE 70 ZODAT DIT ALLEEN DOOR QA GESTART WORDT.


-- _creds = fibaro.basicAuthorization('sjaak.koppejan@.hotmail.com','Leerde75Lopen@');
--na opstart 19-11 56 gebruikt 57 & 10 vrij processor 40%
 rule([[@08:00 & now < 23:00 & $Systeem_Geheugengebruik >= 64 => 
    post(#HC3_restart,+/00:00:10);
    log('🔴🔴🔴🔴🔴🔴 Let Op Hoog geheugen gebruik Restart HC3 na 10 seconden 🔴🔴🔴🔴');
    post(#HC3_restart,+/00:00:10)
    fibaro.alert('push', user,'521 - Let Op Let Op <<< QA  Algemeen >> Let Op Hoog >= 57% geheugen gebruik Restart HC3 na 10 seconden');
    fibaro.call(35, "sendMessage", "521 - Let Op Let Op <<< QA  Algemeen >> Let Op Hoog = 57% geheugen gebruik Restart HC3 na 10 seconden",817111904);
    log('06-E');
wait(0)
]]).start()

 rule([[trueFor(00:05, $Verlichting_Dagdeel == 'Opstaan_Sjaak') & $Systeem_Geheugengebruik >= 64 => 
    post(#HC3_restart,+/00:00:10)
    log('🔴🔴🔴🔴🔴🔴 Let Op Hoog geheugen🔴🔴🔴🔴');
    fibaro.alert('push', user,'521 - Let Op Let Op <<< QA  Algemeen >> Let Op > 53% geheugen gebruik');
    log('06-E2');
wait(0)
]])




--[[
 rule([[23:45..07:00 & api.get('/diagnostics').memory.used > 62 => 
    _creds = fibaro.basicAuthorization('sjaak@koppejan.org','Leerde75Lopen@');
    log('#C:gray#HC3 uptime %.0f hours',(os.time() - api.get('/settings/info').serverStatus)/3600);
    log('#C:red#Restart HC3');
    fibaro.alert('push', user,'521- Let Op Hoog geheugen gebruik Restart HC3 na 10 seconden');
    fibaro.call(35, "sendMessage", "521- Let Op Hoog geheugen gebruik Restart HC3 na 10 seconden",817111904);
    {20}:email = log('Let Op Hoog geheugen gebruik Restart HC3 na 10 seconden
        Systeem_Geheugengebruik = %.2f \n
        Systeem_Uptime = %.2f \n
        ',
        $Systeem_Geheugengebruik,
        $Systeem_Uptime
        );
    wait(00:00:10);
    hc3api.post('/service/reboot',{recovery=false});
    log('06-G');
wait(0)
]]
---------------------------------------------------
rule("log.skyblue('10-RESTART HC3 & ROUTERS')")  
---------------------------------------------------

  --[[rule([[@@01:00 | test3 => 
    $Systeem_Uptime = (os.time() - api.get('/settings/info').serverStatus)/3600;
        log('#C:gray#HC3 uptime %.0f hours',(os.time() - api.get('/settings/info').serverStatus)/3600);
        ram_api.get('/diagnostics').memory.buffer_cache;
       -- ram_used=api.get('/diagnostics').memory.used;
        --ram_cache=api.get('/diagnostics').memory.cache;
        --ram_buffers=api.get('/diagnostics').memory.buffers;
        $Systeem_Geheugengebruik = ram;
        --$Systeem_Buffer = ram_buffers;
        --$Systeem_Cache = ram_cache;
       -- $Systeem_Used = ram_used;
        $Systeem_buffer_cache = ram;
        log('#C:red#$Systeem_Buffer %s%%',memory.buffers);
        log('#C:red#$Systeem_Cache %s%%',memory.cache);
        log('#C:red#$Systeem_Buffer %s%%',memory.used);
        log('#C:red#$Systeem_Cache %s%%',memory.buffer_cache);
        log('#C:red#$Systeem_Geheugengebruik %s%%',ram);
        log('06-A - Systeem info');
wait(0)
]]

     --[[rule([[@@01:00 | test3 => 
    $Systeem_Uptime = (os.time() - api.get('/settings/info').serverStatus)/3600;
        log('#C:gray#HC3 uptime %.0f hours',(os.time() - api.get('/settings/info').serverStatus)/3600);
        ram_used=api.get('/diagnostics').memory.used;
        $Systeem_Used = ram_used;
        log('#C:gray#$Systeem_Used %s%%',ram_used);
        log('06-A - Systeem info');
wait(0)


--[[rule([[($Systeem_Buffer_Cache | $Systeem_Used) | true | test5 =>
    $Systeem_Used_Totaal = $Systeem_Buffer_Cache + $Systeem_Used;
        log('#C:red#$Systeem_Used_Totaal');
        log('06-A4 - Systeem info');
wait(0)

rule([[@08:00 & now < 23:00 & $Systeem__Used_Totaal >= 96 =>
    post(#HC3_restart,+/00:00:10);
    log('🔴🔴🔴🔴🔴🔴 Let Op Hoog geheugen gebruik Restart HC3 na 10 seconden 🔴🔴🔴🔴');
    fibaro.alert('push', user,'521 - Let Op >> Let Op Hoog >= 98% geheugen gebruikt Restart HC3 na 10 seconden');
    fibaro.call(35, "sendMessage", "521 - Let Op Let Op <<< QA  Algemeen >> Let Op Hoog = 98% geheugen gebruikt Restart HC3 na 10 seconden",817111904);
    log('06-2E');
wait(0)
]]



--QA-AA.Restart HC3 of 120
 rule([[#HC3_restart =>
    388:start;
        log('#C:gray#03-C - Historie leegmaken');
    wait(00:00:10);
     fibaro.scene("execute", {120})
        log('#C:gray#03-C - Systeem RESTART');
wait(0)
]])

rule([[@12:45 & month('jan-dec') & wday('sun') =>
    keuken.router_Main:off;
    utility.router_Slave:off;
        log('#C:gray#03-E - keuken.router_Main - Uit');
        log('#C:gray#03-E - utility.router_Slave - Uit');
    wait(0)
    ]])

rule([[trueFor(00:00:15, keuken.router_Main:isOff) =>
    keuken.router_Main:on;
        log('#C:gray#03-G - keuken.router_Main - Aan');
    wait(0)
]])

    rule([[trueFor(00:00:15, utility.router_Slave:isOff) =>
        utility.router_Slave:on;
        log('#C:gray#03-I - utility.router_Slave - Aan');
    wait(0)
    ]])
--[[rule([[test5 => 
        _creds = fibaro.basicAuthorization('sjaak@koppejan.org','Leerde75Lopen@');
        log('#C:red#Restart HC3');
        hc3api.post('/service/reboot',{recovery=false})
    ]]
--sjaak

--[[local http = net.HTTPClient({ timeout = 2000 })
http:request("http://192.168.50.10/api/settings/reboot", {
    options = {
        method = "POST",
        headers = {
            ["Authorization"] = auth,
            ["Content-Type"] = "application/json"
        }
    },
--]]
--LET OP IN SCENE 70 ZODAT DIT ALLEEN DOOR QA GESTART WORDT.


-- _creds = fibaro.basicAuthorization('sjaak.koppejan@.hotmail.com','Leerde75Lopen@');
-- 
 --[[rule([[(@08:00 & now < 23:00 & $Systeem_Geheugengebruik >= 53) => 
    post(#HC3_restart,+/00:00:10);
    log('🔴🔴🔴🔴🔴🔴 Let Op Hoog geheugen gebruik Restart HC3 na 10 seconden 🔴🔴🔴🔴');
    fibaro.alert('push', user,'521 - Let Op Let Op <<< QA  Algemeen >> Let Op Hoog >= 57% geheugen gebruik Restart HC3 na 10 seconden');
    fibaro.call(35, "sendMessage", "521 - Let Op Let Op <<< QA  Algemeen >> Let Op Hoog = 57% geheugen gebruik Restart HC3 na 10 seconden",817111904);
    log('06-2E');
wait(0)
]]

 rule([[@10:00 & wday('sun') => 
    post(#HC3_restart,+/00:00:10);
    log('PERIODIEKE RESTART!!!!!');
    log('06-4E');
wait(0)
]])

 --[[rule([[trueFor(00:05, $Verlichting_Dagdeel == 'Opstaan_Sjaak') & $Systeem_Geheugengebruik >= 52 & $Systeem_Geheugengebruik >= 54 => 
    log('🔴🔴🔴🔴🔴🔴 Let Op Hoog geheugen🔴🔴🔴🔴');
    fibaro.alert('push', user,'521 - Let Op Let Op <<< QA  Algemeen >> Let Op > 52/54% geheugen gebruik');
    log('06-F');
wait(0)


 rule([[@{08:00, catch} & now < 23:45 & $Systeem_Geheugengebruik > 54 & $Systeem_Geheugengebruik <= 56 => 
    log('🔴🔴🔴🔴🔴🔴 Let Op Hoog geheugen🔴🔴🔴🔴');
    fibaro.alert('push', user,'521 - Let Op Let Op <<< QA  Algemeen >> Let Op > 54/56% geheugen gebruik');
    log('06-F2');
wait(0)



 rule([[@{08:00, catch} & now < 23:45 & $Systeem_Geheugengebruik >= 56 => 
    log('🔴🔴🔴🔴🔴🔴 Let Op Hoog geheugen🔴🔴🔴🔴');
    fibaro.alert('push', user,'521 - Let Op Let Op <<< QA  Algemeen >> Let Op  > 56% geheugen gebruik');
    log('06-F4');
wait(0)
]]




---------------------------------------------------
rule("log.skyblue('50-GORDIJN LICHT OCHTEND')")  
---------------------------------------------------
--https://www.sunrise-and-sunset.com/nl/sun/nederland/vlissingen/2024/juli


rule([[$Gordijn_Licht == 'Avond' =>
log.limegreen('vertraging door:
Zwaar_Bewolkt + 00:02 -
Geheel_Bewolkt + 00:05 -
Half_Bewolkt + 00:10 -
Licht_Bewolkt + 00:15 -
Onbewolkt + 00:20') 
]])
        
 rule([[$Gordijn_Licht == 'Ochtend' =>
log.limegreen('vertraging door:
onbewolkt >> +00:00 -
Licht bewolkt >> +00:10 -
Half_Bewolkt >> +00:15 -
Geheel_Bewolkt >> +00:20 -
Zwaar_Bewolkt >> +00:25')
]])

--(keuken.radar:isOn | eethoek.radar:isOn | zithoek.radar:isOn | hal.radar:isOn )
--@sunrise 08:50-08:26 >> licht 07:00 << bewolking 00:00-00:15
 rule([[@sunrise+00:13 & $Locatie_Bewoners == 'Aanwezig' & month('jan') & $Gordijn_Licht ~= 'Ochtend' => 
    $Gordijn_Licht = 'Ochtend';          
        log.pink('50-A >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Licht == Ochtend %s uur',HM(sunrise));
        log.limegreen('50-A >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)    
]]).start()

--@sunrise 08:24-07:36 >> licht 07:00 << bewolking 00:00-00:15
 rule([[@sunrise+00:10 & $Locatie_Bewoners == 'Aanwezig' & month('feb') & $Gordijn_Licht ~= 'Ochtend' => 
    $Gordijn_Licht = 'Ochtend';          
        log.pink('50-C >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Licht == Ochtend %s uur',HM(sunrise));
        log.limegreen('50-C >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)    
]]).start()

--@sunrise 07:31-07:24 >> licht 07:00 << bewolking 00:00-00:15
--zomertijd omschakeling loopt paar dagen scheef
 rule([[@sunrise & $Locatie_Bewoners == 'Aanwezig' & month('mar') =>
    $Gordijn_Licht = 'Ochtend';     
        log.pink('50-D >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Licht == Ochtend %s uur',HM(sunrise));
        log.limegreen('50-D >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)   
]]).start()

rule([[$Locatie_Bewoners == 'Aanwezig' & $Verlichting_Dagdeel == 'Opstaan_Sjaak' & now > sunrise =>
    $Gordijn_Licht = 'Ochtend';     
        log.pink('50-E >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Licht == Ochtend %s uur',HM(sunrise));
        log.limegreen('50-E >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)  
]]).start()

--01 april actueel sunrise 07:21
--30 april actueel sunrise 06:20
--@sunrise 07:21-06:20 >> licht 07:00 << bewolking 00:00-00:15
 rule([[@sunrise & $Locatie_Bewoners == 'Aanwezig' & month('apr') & $Gordijn_Licht ~= 'Ochtend'  => 
    $Gordijn_Licht = 'Ochtend';     
        log.pink('50-F >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Licht == Ochtend %s uur',HM(sunrise));
        log.limegreen('50-F >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)   
]]).start()

--01 mei actueel sunrise 06:17
--@sunrise 06:18-05:36 >> licht 07:00 << bewolking 00:00-00:15
 rule([[@sunrise+00:15 & $Locatie_Bewoners == 'Aanwezig' & month('may') & $Gordijn_Licht ~= 'Ochtend'  =>
     $Gordijn_Licht = 'Ochtend';     
        log.pink('50-I>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Licht == Ochtend %s uur',HM(sunrise+00:30));
        log.limegreen('50-I >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)    
]]).start()

--@sunrise 05:30-05:35 >> licht 07:00 << bewolking 00:00-00:15
 rule([[@sunrise+00:30 & $Locatie_Bewoners == 'Aanwezig' & month('jun') & $Gordijn_Licht ~= 'Ochtend' => 
    $Gordijn_Licht = 'Ochtend';  
        log.pink('50-K >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Licht == Ochtend %s uur',HM(sunrise+01:05));
        log.limegreen('50-K >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)    
]]).start()

--@sunrise 05:34-06:10 >> licht 07:00 << bewolking 00:00-00:15
 rule([[(@sunrise+00:35 & $Locatie_Bewoners == 'Aanwezig' & month('jul')) & $Gordijn_Licht ~= 'Ochtend'  =>
    $Gordijn_Licht = 'Ochtend';     
        log.pink('50-M >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Licht == Ochtend %s uur',HM(sunrise+01:00));
        log.limegreen('50-M >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)   
]]).start()

--@sunrise 06:11-07:00 >> licht 07:00 << bewolking 00:00-00:15
 rule([[(@sunrise & $Locatie_Bewoners == 'Aanwezig' & month('aug')) & day('1-20') & $Gordijn_Licht ~= 'Ochtend'  => 
    $Gordijn_Licht = 'Ochtend';     
        log.pink('50-P >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Licht == Ochtend %s uur',HM(sunrise+00:30));
        log.limegreen('50-P >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)    
]]).start()

 rule([[(@sunrise & $Locatie_Bewoners == 'Aanwezig' & month('aug')) & day('20-30') & $Gordijn_Licht ~= 'Ochtend'  => 
    $Gordijn_Licht = 'Ochtend';     
        log.pink('50-P >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Licht == Ochtend %s uur',HM(sunrise+00:30));
        log.limegreen('50-P >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)    
]]).start()

--@sunrise 07:00-07:45 >> licht 07:00 << bewolking 00:00-00:15
 rule([[@sunrise & $Locatie_Bewoners == 'Aanwezig' & month('sep') & $Gordijn_Licht ~= 'Ochtend' =>
    $Gordijn_Licht = 'Ochtend';     
        log.pink('50-R >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Licht == Ochtend %s uur',HM(sunrise));
        log.limegreen('50-R >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)    
]]).start()
--log.limegreen('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Weer_Bewolking is %s',$Weer_Bewolking);

--@sunrise 07:47-08:30 >> licht 07:00 << bewolking 00:00-00:15
--wintertijd omschakeling loopt paar dagen scheef
 rule([[@sunrise & $Locatie_Bewoners == 'Aanwezig' & month('oct') =>
    $Gordijn_Licht = 'Ochtend';     
        log.pink('50-T >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Licht == Ochtend %s uur',HM(sunrise));
        log.limegreen('50-T >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking is %s',$Weer_Bewolking);
        log('50-K');
wait(0)    
]]).start()

--@sunrise 07:40-08:35 >> licht 07:00 << bewolking 00:00-00:15
 rule([[@sunrise & $Locatie_Bewoners == 'Aanwezig' & month('nov') =>
    $Gordijn_Licht = 'Ochtend';     
        log.pink('50-V >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Licht == Ochtend %s uur',HM(sunrise));
        log.limegreen('50-V >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking is %s',$Weer_Bewolking);
        log('50-L');
wait(0)    
]]).start()

 rule([[@sunrise & $Locatie_Bewoners == 'Aanwezig' & month('dec') =>
    $Gordijn_Licht = 'Ochtend';  
        log.pink('50-Y >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Licht == Ochtend %s uur',HM(sunrise));
        log.limegreen('50-Y >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)    
]]).start()

---------------------------------------------------- 
rule("log.skyblue('51-WEER TEMPERATUUR')")
-------------------------------------------------

rule([[weer.buiten_Temperatuur:value | true =>
        log.coral('51-A weer.buiten_Temperatuur:value %s',weer.buiten_Temperatuur:value);
wait(0)    
]]).start()

---------------------------------------------------- 
rule("log.skyblue('52-GORDIJN LICHT OCHTEND AFWEZIG')")
--------------------------------------------------------


 rule([[@07:30+rnd(-00:15,00:15) & (month('jan') | month('feb') | month('mar') | month('apr') | month('oct') | month('nov') | month('dec')) & $Locatie_Bewoners == 'Afwezig' & $Gordijn_Licht ~= 'Ochtend' => 
    $Gordijn_Licht = 'Ochtend';          
          log.pink('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht == Ochtend %s',$Gordijn_Licht);
        log('52-B');
wait(0)   
]]).start()

 rule([[@07:00 & (month('may') | month('jun') | month('jul') | month('aug') | 
month('sep')) & $Locatie_Bewoners == 'Afwezig' & $Gordijn_Licht ~= 'Ochtend' => 
    $Gordijn_Licht = 'Ochtend';          
          log.pink('52-B - >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht == Ochtend %s',$Gordijn_Licht);
wait(0)   
]]).start()

------------------------------------------------------
rule("log.skyblue('54-GORDIJN BEWOLKING OCHTEND')")  
------------------------------------------------------

---- 0 = gesloten
----98 = bijna geheel open
--& now < 23:00
--08.25-.15-.23
--Ochtend bij bewolking later open 
-- 
--& $Gordijn_Bewolking ~= 'Ochtend'

 rule([[$Gordijn_Licht == 'Ochtend' & $Weer_Bewolking == 'Onbewolkt' & zithoek.gordijn:value < 20 => 
        post(#gordijn_Bewolking_Ochtend,+/00:01);
        log.magenta('54-2A - #gordijn_Bewolking_Ochtend - vertraagd');
        log.pink('54-2A >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Ochtend');
wait(0)
 ]]).start()

 rule([[$Gordijn_Licht == 'Ochtend' & $Weer_Bewolking == 'Geen_Bewolking' & zithoek.gordijn:value < 20 => 
        post(#gordijn_Bewolking_Ochtend,+/00:01);
        log.magenta('54-4A - #gordijn_Bewolking_Ochtend - vertraagd');
        log.pink('54-4A >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Ochtend');
wait(0)
 ]]).start()

 rule([[$Gordijn_Licht == 'Ochtend' & $Weer_Bewolking == 'Licht_Bewolkt' & zithoek.gordijn:value < 20 => 
        post(#gordijn_Bewolking_Ochtend,+/00:05);
        log.magenta('54-6A - #gordijn_Bewolking_Ochtend - vertraagd');
        log.pink('54-6A >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Ochtend');
wait(0)
 ]]).start()

 rule([[$Gordijn_Licht == 'Ochtend' & $Weer_Bewolking == 'Half_Bewolkt' & zithoek.gordijn:value < 20 => 
        post(#gordijn_Bewolking_Ochtend,+/00:10);
        log.magenta('54-8A - gordijn_Bewolking_Ochtend - vertraagd');
        log.pink('54-8A>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Ochtend');
wait(0)
 ]]).start()

--@{05:00, catch} & now < 09:30 &
 rule([[$Gordijn_Licht == 'Ochtend' & $Weer_Bewolking == 'Geheel_Bewolkt' & zithoek.gordijn:value < 20 =>  
        post(#gordijn_Bewolking_Ochtend,+/00:12);
        log.magenta('54-10A - #gordijn_Bewolking_Ochtend - vertraagd');
        log.pink('54-10A>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Ochtend');
wait(0) 
 ]]).start()

 rule([[$Gordijn_Licht == 'Ochtend' & $Weer_Bewolking == 'Zwaar_Bewolkt' & zithoek.gordijn:value < 20 => 
        post(#gordijn_Bewolking_Ochtend,+/00:14);
        log.magenta('54-12A - #gordijn_Bewolking_Ochtend - vertraagd');
        log.pink('54-12A >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Ochtend');
wait(0)
]]).start()



--30 april 2026:
--logica gzithoek.ordijn is omgedraaid
--$Gordijn_Status_Zithoek == 'Is_Gesloten' >>> $Gordijn_Status_Zithoek == 'Is_Gesloten' 
--$Gordijn_Status_Zithoek == 'Is_Geopend' >>> $Gordijn_Status_Zithoek == 'Is_Geopend' >

-- mocht bovenstaande niet werken dan als backup:
 rule([[$Gordijn_Licht == 'Ochtend' & trueFor(00:01, $Weer_Bewolking == 'Onbewolkt') & $Gordijn_Bewolking ~= 'Ochtend' => 
    $Gordijn_Bewolking = 'Ochtend'; 
        log.pink('54-O >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Ochtend');
wait(0)
]]).start()

 rule([[$Gordijn_Licht == 'Ochtend' & $Gordijn_Status_Zithoek == 'Is_Gesloten' & trueFor(00:06, $Weer_Bewolking == 'Licht_Bewolkt') & $Gordijn_Bewolking ~= 'Ochtend' => 
    $Gordijn_Bewolking = 'Ochtend'; 
        log.pink('54-P >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Ochtend');
wait(0)
]]).start()

 rule([[$Gordijn_Licht == 'Ochtend'  & 
$Gordijn_Status_Zithoek == 'Is_Gesloten' &
trueFor(00:11, $Weer_Bewolking == 'Half_Bewolkt') & $Gordijn_Bewolking ~= 'Ochtend' => 
$Gordijn_Bewolking = 'Ochtend'; 
        log.pink('54-Q >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Ochtend');
wait(0)
]]).start()

 rule([[$Gordijn_Licht == 'Ochtend'  & 
$Gordijn_Status_Zithoek == 'Is_Gesloten' &
trueFor(00:13, $Weer_Bewolking == 'Geheel_Bewolkt') & $Gordijn_Bewolking ~= 'Ochtend' => 
$Gordijn_Bewolking = 'Ochtend'; 
        log.pink('54-R >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Ochtend');
wait(0)
]]).start()

 rule([[$Gordijn_Licht == 'Ochtend'  & 
$Gordijn_Status_Zithoek == 'Is_Gesloten' &
trueFor(00:15, $Weer_Bewolking == 'Zwaar_Bewolkt') & $Gordijn_Bewolking ~= 'Ochtend' => 
$Gordijn_Bewolking = 'Ochtend'; 
        log.pink('54-S >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Gordijn_Bewolking = Ochtend');
wait(0)
]]).start()

-- dit anders krijg je vaker gordijnen openen of sluiten ook met zon>> sluiten

 rule([[#gordijn_Bewolking_Ochtend  & $Gordijn_Bewolking ~= 'Ochtend' =>
    $Gordijn_Bewolking = 'Ochtend'; 
        log.pink('54-T >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Ochtend');
wait(0)
]]).start()


-------------------------------------------------
rule("log.skyblue('60-LICHT AVOND')")
----------------------------------------------- 

 rule([[@sunset-00:40 & month('jan') & $Gordijn_Licht ~= 'Avond' =>
   $Gordijn_Licht = 'Avond';         
        log.pink('60-A >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - januari');
wait(0)
]]).start()

 rule([[@sunset-00:38 & month('feb') & $Gordijn_Licht ~= 'Avond' =>  
   $Gordijn_Licht = 'Avond';         
         log.pink('60-B >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - februari');
wait(0)
]]).start()

 -- -00:36
 rule([[@sunset-00:37 & month('mar') & $Gordijn_Licht ~= 'Avond' =>
    $Gordijn_Licht = 'Avond';        
        log.pink('60-D >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - maart');
wait(0)
]]).start()

 rule([[@sunset-00:34 & month('apr') & $Gordijn_Licht ~= 'Avond' =>
    $Gordijn_Licht = 'Avond';        
        log.pink('60-D >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - maart');
wait(0)
]]).start()

-- -3 min om jalouzieen te sluiten
 rule([[@sunset-00:55 & month('may') & $Gordijn_Licht ~= 'Avond' =>
    $Gordijn_Licht = 'Avond';        
        log.pink('60-D >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - maart');
wait(0)
]]).start()

-- -00:30
--22-06 van 01:00 naar 00:50
--minus 35 min
-- -3 min om jalouzieen te sluiten
 rule([[@sunset-00:47 & month('jun') & $Gordijn_Licht ~= 'Avond' =>
    $Gordijn_Licht = 'Avond';   
        log.pink('60-F >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - juni');
        log.limegreen('60-F >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)
]]).start()
-- -00:25
-- -3 min om jalouzieen te sluiten
 rule([[@sunset-00:42 & month('jul') & $Gordijn_Licht ~= 'Avond' =>
    $Gordijn_Licht = 'Avond';   
        log.pink('60-G >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - juli ');
        log.limegreen('60-G >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)
]]).start()

-- -3 min om jalouzieen te sluiten
 rule([[@sunset-00:25 & month('aug') & $Gordijn_Licht ~= 'Avond' =>  
   $Gordijn_Licht = 'Avond';         
        log.pink('60-I >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - augustus');
wait(0)
]]).start()
--was36

-- -3 min om jalouzieen te sluiten
--5 min eerder sluiten was al donker
--rule([[/09/01/00:00../09/15/00:00 =>
 rule([[/09/01/00:00../09/15/00:00 & @sunset-00:35 & $Gordijn_Licht ~= 'Avond' =>
    $Gordijn_Licht = 'Avond';        
        log.pink('60-J >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - september');
        log.limegreen('60-J >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)
]]).start()

 rule([[/09/01/00:00../09/15/00:00 & @sunset-00:32 & $Gordijn_Licht ~= 'Avond' =>
    $Gordijn_Licht = 'Avond';        
        log.pink('60-J >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - september');
        log.limegreen('60-J >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)
]]).start()

 rule([[@sunset-00:38 & month('sep') & $Gordijn_Licht ~= 'Avond' =>
    $Gordijn_Licht = 'Avond';        
        log.pink('60-J >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - september');
        log.limegreen('60-J >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)
]]).start()

 rule([[/10/01/00:00../10/15/00:00 & @sunset-00:45 & month('oct') & $Gordijn_Licht ~= 'Avond' =>  
   $Gordijn_Licht = 'Avond';    
        log.pink('60-K >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - 1e helft');
        log.limegreen('60-K >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)
]]).start()

 rule([[/10/15/00:00../10/31/00:00 & @sunset-00:50 & month('oct') & $Gordijn_Licht ~= 'Avond' =>  
   $Gordijn_Licht = 'Avond';    
        log.pink('60-K >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - 1e helft');
        log.limegreen('60-K >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)
]]).start()

 rule([[@sunset-01:00 & month('nov') & $Gordijn_Licht ~= 'Avond' =>
   $Gordijn_Licht = 'Avond';         
        log.pink('60-L >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - november');
        log.limegreen('60-L >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)
]]).start()

 rule([[@sunset-00:08 & month('dec') & $Gordijn_Licht ~= 'Avond' =>  
   $Gordijn_Licht = 'Avond';    
        log.pink('60-M >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - december');
        log.limegreen('60-M >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Weer_Bewolking is %s',$Weer_Bewolking);
wait(0)
]]).start()

 rule([[@{sunset-00:15, catch} & now < sunrise-01:10 & $Gordijn_Licht ~= 'Avond' =>
    $Gordijn_Licht = 'Avond';           
        log.pink('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Licht = Avond - NOOD??');
]]).start()

--1 uur voor zonsondergang >> $Gordijn_Licht = 'Avond'
-- bewolking te verdelen 21:54 zonsondergang gordijn dicht bij onbewolkt.
--gordijn dicht bij zwaarbewolkt om 21:00
--4 min verschil nu om > 86% 0 min te wachten
--01:10 ipv 01:00 14 juni

---------------------------------------------------
rule("log.skyblue('62-GORDIJN-BEWOLKING AVOND')")  
---------------------------------------------------

--operation cancelled is een foutmelding van liveweer!!!
--setember geheel_bewolkt mag 5 min eerder

--[[ rule([[@00:00 & (month('dec') | month('jan') | month('feb') =>
 & (month('mar') | month('apr') | month('may') =>
(month('jun') | month('jul') | month('aug') | month('sep') =>
 (month('oct') | month('nov') | month('ndec') =>
]]   

--[[rule([[test5 =>
            post(#bewolking_Avond,+/00:02); 
            log.magenta('#bewolking_Avond - Vertraagd 2 min');
            ]]


rule([[#bewolking_Avond =>
    $Gordijn_Bewolking = 'Avond';
        log.lavender('$Gordijn_Bewolking == Avond');
        log.pink('62-2A Door #bewolking_Avond >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Avond');
    wait(0)
    ]])
--@{16:00, catch} & now < 23:00 & 
--35 mei 21:38 licht
-- vertraging om jalouzien te sluiten. +03 min
 rule([[@{16:00, catch} & now < 23:00 & $Gordijn_Licht == 'Avond' & $Weer_Bewolking == 'Zwaar_Bewolkt' & 
 zithoek.gordijn:value > 50 => 
        post(#bewolking_Avond,+/00:05); 
        log.magenta('62-2C - #bewolking_Avond - vertraagd - 2 min');
        log.pink('62-2C >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Avond wordt ingesteld na >>>  2 min');
        log.lavender('62-2C - $Gordijn_Licht == Avond >>> actueel >>> %s',$Gordijn_Licht);
        log.lavender('62-2C - Weer_Bewolking == Zwaar_Bewolkt >>> %s',$Weer_Bewolking);
wait(0)
]])

--@{16:00, catch} & now < 23:00 & 
rule([[$Gordijn_Licht == 'Avond' & $Weer_Bewolking == 'Geheel_Bewolkt' & 
 zithoek.gordijn:value > 50 =>
        post(#bewolking_Avond,+/00:08); 
        log.magenta('62-4C #bewolking_Avond - vertraagd - 5 min');
        log.pink('62-4C >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Avond wordt ingesteld na >>>  5 min');
wait(0)
]])

--{@16:00, catch} & now < 23:00 & 
rule([[$Gordijn_Licht == 'Avond' & $Weer_Bewolking == 'Half_Bewolkt' & 
 zithoek.gordijn:value > 50 =>
        post(#bewolking_Avond,+/00:13); 
        log.magenta('62-6C - #bewolking_Avond - vertraagd - 10 min');
        log.pink('62-6C >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Avond wordt ingesteld na >>>  10 min');
wait(0)
]])

rule([[$Gordijn_Licht == 'Avond' & $Weer_Bewolking == 'Licht_Bewolkt' & 
 zithoek.gordijn:value > 50 =>
        post(#bewolking_Avond,+/00:18); 
        log.magenta('62-8C - #bewolking_Avond - vertraagd 15 min');
        log.pink('62-8C >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Avond wordt ingesteld na >>>  15 min');
wait(0)
]])

--@{16:00, catch} & now < 23:00 & 
rule([[$Gordijn_Licht == 'Avond' & $Weer_Bewolking == 'Onbewolkt' & 
 zithoek.gordijn:value > 50 =>
        post(#bewolking_Avond,+/00:23); 
        log.magenta('62-10C - #bewolking_Avond - vertraagd 20 min');
        log.pink('62-10C >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Gordijn_Bewolking = Avond wordt ingesteld na >>>  20 min');
wait(0)
]])

rule([[$Gordijn_Bewolking | true =>
log.pink('62-F - $Gordijn_Bewolking >>> %s',$Gordijn_Bewolking);
wait(0)
]]).start()


rule([[$Weer_Bewolking | true =>
log.pink('62-H - $Weer_Bewolking >>> %s',$Weer_Bewolking);
wait(0)
]]).start()

----------------------------------------------------------- 
rule("log.skyblue('68-TEMPERATUUR ZITHOEK GORDIJN')")
------------------------------------------------------------

 rule([[$Verlichting_Dagdeel == 'Opstaan_Sjaak' & 
$Temp_Start_Waarde_Laptop > meetkamer.temp_Laptop:value =>
    $Temp_Start_Waarde_Laptop = meetkamer.temp_Laptop:value;
        log.red('68-2A >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Temp_Start_Waarde_Laptop gecorrigeerd %s °C',$Temp_Start_Waarde_Laptop);
        log.yellow('meetkamer.temp_Laptop >>>> %s °C',meetkamer.temp_Laptop:value);
        wait(0)
]]).start()

 rule([[month('may-sep') & $Gordijn_Temp_Meetperiode ~= 'Ja' =>
    $Gordijn_Temp_Meetperiode = 'Ja';
        log.pink('68-2C - $Gordijn_Temp_Meetperiode == Ja');
        wait(0)
]]).start()


 rule([[month('oct-apr') & $Gordijn_Temp_Meetperiode ~= 'Nee' =>
    $Gordijn_Temp_Meetperiode = 'Nee';
        log.pink('68-4C - $Gordijn_Temp_Meetperiode == Nee');
        wait(0)
]]).start()

 rule([[$Gordijn_Temp_Meetperiode == 'Nee' & $Gordijn_Bewolking == 'Ochtend' =>
    $Temp_Start_Waarde_Laptop = meetkamer.temp_Laptop:value; 
        log.pink('68-2E >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Temp_Start_Waarde_Laptop >>>> %s °C',$Temp_Start_Waarde_Laptop);
        log.pink('68-2E >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Temp_Delta_Laptop >>>> %s °C',$Temp_Delta_Laptop);
        log.yellow('68-2E - meetkamer.temp_Thermostaat >>>> %s °C',meetkamer.temp_Thermostaat:value);
        log.yellow('68-2E - meetkamer.temp_Laptop >>>> %s °C',meetkamer.temp_Laptop:value);
        log('68-F');
wait(0)
]]).start()

 rule([[$Gordijn_Temp_Meetperiode == 'Ja' & ($Gordijn_Bewolking == 'Ochtend' | $Verlichting_Dagdeel == 'Opstaan_Beide') =>
    $Temp_Start_Waarde_Laptop = meetkamer.temp_Laptop:value; 
        log.pink('68-G >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Temp_Start_Waarde_Laptop >>>> %s °C',$Temp_Start_Waarde_Laptop);
        log.pink('68-G >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Temp_Delta_Laptop >>>> %s °C',$Temp_Delta_Laptop);
        log.yellow('68-G - meetkamer.temp_Thermostaat >>>> %s °C',meetkamer.temp_Thermostaat:value);
        log.yellow('68-G - meetkamer.temp_Laptop >>>> %s °C',meetkamer.temp_Laptop:value);
        log('68-G');
wait(0)
]]).start()

--Calibratie zie hierboven
--[[ rule([[@@01:00 | test3 == true =>
log.yellow('meetkamer.temp_Laptop:value >> %.1f °C',meetkamer.temp_Laptop:value);
log.pink('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Temp_Start_Waarde_Laptop >> %.1f °C',$Temp_Start_Waarde_Laptop);
log.pink('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Temp_Delta_Laptop >> %.1f °C',$Temp_Delta_Laptop);
log.yellow('meetkamer.temp_Thermostaat:value >> %.1f °C',meetkamer.temp_Thermostaat:value);
        log('68-I');
wait(0)
]]

--@@00:10 & 
 rule([[$Gordijn_Temp_Meetperiode == 'Nee' & $Verlichting_Dagdeel == 'Opstaan_Sjaak' & 
 (meetkamer.temp_Laptop:value > 21 & meetkamer.temp_Laptop:value < 35) & (meetkamer.temp_Laptop:value | true) =>
    $Temp_Delta_Laptop = meetkamer.temp_Laptop:value - 
    $Temp_Start_Waarde_Laptop; 
        log.yellow('68-J - meetkamer.temp_Thermostaat >>>> %s °C',meetkamer.temp_Thermostaat:value);
        log.yellow('68-J - meetkamer.temp_Laptop >>>> %s °C',meetkamer.temp_Laptop:value);
        log.pink('68-J >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Temp_Start_Waarde_Laptop >>>> %s °C',$Temp_Start_Waarde_Laptop);
        log.pink('68-J >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Temp_Delta_Laptop >>>> %s °C',$Temp_Delta_Laptop);
wait(0)
]]).start()

rule([[@{06:00, catch} & now < 12:00 & $Gordijn_Temp_Meetperiode == 'Nee' & 
 meetkamer.temp_Laptop:value > 21 & meetkamer.temp_Laptop:value < 35 =>
    $Temp_Delta_Laptop = meetkamer.temp_Laptop:value - 
    $Temp_Start_Waarde_Laptop; 
    log.yellow('68-2J - meetkamer.temp_Laptop >>>> %s °C',meetkamer.temp_Laptop:value);
        log.pink('68-2J >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Temp_Start_Waarde_Laptop >>>> %s °C',$Temp_Start_Waarde_Laptop);
        log.pink('68-2J >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Temp_Delta_Laptop >>>> %s °C',$Temp_Delta_Laptop);
wait(0)
]]).start()

 rule([[$Gordijn_Temp_Meetperiode == 'Ja' =>
    $Temp_Start_Waarde_Laptop = meetkamer.temp_Laptop:value; 
        log.pink('68-L >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Temp_Start_Waarde_Laptop >>>> %s °C',$Temp_Start_Waarde_Laptop);
        log.yellow('68-L - De startwaarde laptop is nu gelijk aan temp_Laptop om geen interventie met gordijnen savonds te hebben');
wait(0)
]]).start()



-------------------------------------------------
rule("log.skyblue('69-TEMPERATUUR')")
-------------------------------------------------

    rule("zithoek.last_Vloer = 0 ")

--[[ rule([[$Gordijn_Temp_Meetperiode == 'Nee' & math.abs(meetkamer.temp_Vloer_Verwarming_Aanvoer:value - zithoek.last_Vloer) >= 0.5 =>
    zithoek.last_Vloer = meetkamer.temp_Vloer_Verwarming_Aanvoer:value; 
        log.yellow('meetkamer.temp_Vloer_Verwarming_Aanvoer:value %.1f °C',meetkamer.temp_Vloer_Verwarming_Aanvoer:value);
        log.yellow('meetkamer.temp_Vloer_Verwarming_Retour:value %.1f °C',meetkamer.temp_Vloer_Verwarming_Retour:value);
        log.yellow('meetkamer.temp_Vloer_Woongedeelte:value %.1f °C',meetkamer.temp_Vloer_Woongedeelte:value);
        log('69-A');
wait(0)
]]

---------------------------------------------------------------
rule("log.skyblue('70-REPORTING TEMPERATUREN VERWARMING')") 
----------------------------------------------------------------

-- algemeen voor rapporteren temperaturen
-- wordt geprint in debug

function exportTemps(startDate,stopDate,deviceId)
  local function toEpoc(t)
    local y,m,d = t:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
    return os.time{year =tonumber(y),month=tonumber(m),day=tonumber(d),hour =0}
  end
  local data = api.get(string.format("/temperature/%s/%s/summary-graph/devices/temperature/%s",toEpoc(startDate),toEpoc(stopDate),deviceId))
  if data == nil then
    -- fibaro.warning(__TAG,"Couldnt get temp data")
  end
  for _,d in ipairs(data or {}) do d[1] = d[1]//1000 end
  return data or {}
end

local function printData(data)
  for _,d in ipairs(data) do
    print(string.format("%s => %.02f°",os.date("%x %X",d[1]),d[2])) 
  end
end


--specifiek apparaat

local data = exportTemps("2024-01-26","2024-01-31",1356)
printData(data)

local data = exportTemps("2024-01-26","2024-01-31",804)
printData(data)

local data = exportTemps("2024-01-26","2024-01-31",1352)
printData(data)

local data = exportTemps("2024-01-26","2024-01-31",1290)
printData(data)

local data = exportTemps("2024-01-26","2024-01-31",1291)
printData(data)

local data = exportTemps("2024-01-26","2024-01-31",570)
printData(data)

local data = exportTemps("2024-01-26","2024-01-31",1578)
printData(data)

local data = exportTemps("2024-01-26","2024-01-31",1174)
printData(data)

local data = exportTemps("2024-01-26","2024-01-31",265)
printData(data)

local data = exportTemps("2024-01-26","2024-01-31",102)
printData(data)
--]]
--------------------------------------------------
rule("log.skyblue('71-RAPPORTAGE TEMPERATUREN')") 
-----------------------------------------------------


--https://forum.fibaro.com/topic/72546-export-temperature-chart-data/page/3/#comment-277226

--------------------------------------------------
rule("log.skyblue('72-PRINT TEMPERATUUR')")
-------------------------------------------------------

 rule([[@@02:00 & @{07:00, catch} & now < 21:00 =>
log.byzantine('72-A - Status temperaturen Appartement:');
log.yellow('temp_Bron = %.1f °C',meetkamer.temp_Bron:value);
log.yellow('temp_Vloer_Verwarming_Aanvoer = %.1f °C',meetkamer.temp_Vloer_Verwarming_Aanvoer:value);
log.yellow('temp_Vloer_Verwarming_Retour = %.1f °C',meetkamer.temp_Vloer_Verwarming_Retour:value);
log.yellow('temp_Vloer_Woongedeelte = %.1f °C',meetkamer.temp_Vloer_Woongedeelte:value);
log.yellow('meetkamer.temp_Thermostaat  -3.5 correctie = %.1f °C ',meetkamer.temp_Thermostaat:value- 3.5);
log.yellow('meetkamer.temp_Laptop:value = %.1f °C', meetkamer.temp_Laptop:value);
log.yellow('badkamer.temp_Deur = %.1f °C',badkamer.temp_Deur:value);
log.yellow('slaapkamer.temp_Deur = %.1f °C',slaapkamer.temp_Deur:value);
log.yellow('logeerkamer.temp_Deur = %.1f °C',logeerkamer.temp_Deur:value);
wait(0)
]])

-----------------------------------------------------
rule("log.skyblue('73-KLEUR VAN DE DAG')")
---------------------------------------------------

--helder = (lezen vervallen)
--energie = (concentreren vervallen)
--ontspannen
--rusten
--appartement.Apaartement

--[[fibaro.call(id,"setDim",1) -- there is no ER command yet for this
:value = 50

There is also a QuickApp:fadeTo(start, stop,delay) command that does it in one
fibaro.call(id,"fadeTo",1,50,3000) -- turn on and fade from 1 to 50 in 3s
]]




rule([[$Verlichting_Dagdeel == 'Opstaan_Sjaak' & $Verlichting_Kleur_Van_De_Dag ~= 'Energie' =>
    $Verlichting_Kleur_Van_De_Dag = 'Energie';
        log.pink('73-A >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Verlichting_Kleur_Van_De_Dag = Energie');
wait(0)
    ]]).start()

rule([[@10:00 & $Verlichting_Kleur_Van_De_Dag ~= 'Concentreren'=>
        log.pink('73-C >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Verlichting_Kleur_Van_De_Dag = Concentreren');
wait(0)
    ]]).start()

-- moet lezen worden of Magneto
 rule([[@{12:00, catch} & now < 22:00 & $Verlichting_Kleur_Van_De_Dag ~= 'Helder' & $Media_TV == 'Aan' =>
    $Verlichting_Kleur_Van_De_Dag = 'Helder';
        log.pink('73-E >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Verlichting_Kleur_Van_De_Dag = Helder');
wait(0)
    ]]).start()


 rule([[@{19:00, catch} & now < 22:00 & $Verlichting_Kleur_Van_De_Dag ~= 'Magneto' & $Media_TV == 'Uit' =>
    $Verlichting_Kleur_Van_De_Dag = 'Magneto';
        log.pink('73-2D - >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Verlichting_Kleur_Van_De_Dag = Magneto');
wait(0)
    ]]).start()

 rule([[once($Verlichting_Dagdeel == 'Avond') & $Media_TV == 'Aan' & $Verlichting_Kleur_Van_De_Dag ~= 'Ontspannen' =>
    $Verlichting_Kleur_Van_De_Dag = 'Ontspannen';
        log.pink('73-G >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Verlichting_Kleur_Van_De_Dag = Ontspannen');
wait(0)
    ]]).start()

--moet ontspannen worden
 rule([[once($Verlichting_Dagdeel == 'Avond') & $Media_TV == 'Uit' & $Verlichting_Kleur_Van_De_Dag ~= 'Rusten' =>
    $Verlichting_Kleur_Van_De_Dag = 'Rusten';
        log.pink('73-H >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Verlichting_Kleur_Van_De_Dag = Rusten');
wait(0)
    ]]).start()

 rule([[once($Verlichting_Dagdeel == 'Slapen') & $Verlichting_Kleur_Van_De_Dag ~= 'Rusten' =>
    $Verlichting_Kleur_Van_De_Dag = 'Rusten';
        log.pink('73-K >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Verlichting_Kleur_Van_De_Dag = Rusten');
wait(0)
    ]]).start()


------------------------------------------------------
rule("log.skyblue('76-AFWEZIG_UIT')")
----------------------------------------------------

--(@23:15+rnd(-00:07:30,00:07:30) |
 rule([[@00:00+rnd(-00:07:30,00:07:30) & $Locatie_Bewoners == 'Afwezig' => 
       $Verlichting_Appartement = 'Afwezig_Uit';
       $Verlichting_Dagdeel = 'Nacht';
       log.pink('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Verlichting_Dagdeel == Nacht');
       log.pink('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Verlichting_Appartement == Afwezig_Uit');
       log('76-A');
wait(0)
]]).start()


------------------------------------------------------
rule("log.skyblue('80-WIND')")
----------------------------------------------------

 rule([[weer.windrichting:value >= 0 & weer.windrichting:value <= 400 =>case
|| weer.windrichting:value >348.75 & weer.windrichting:value <= 11.25 >> 
    $Weer_Windroos = 'Noord'
|| weer.windrichting:value >11.25 & weer.windrichting:value <= 33.75 >> 
    $Weer_Windroos = 'Noord-Noord ten Oosten'
|| weer.windrichting:value >33.75 & weer.windrichting:value <= 56.25 >> 
    $Weer_Windroos = 'Noord-Oost'
|| weer.windrichting:value >56.25 & weer.windrichting:value <= 78.75 >> 
    $Weer_Windroos = 'Oost-Noord ten Oosten'
|| weer.windrichting:value >78.75 & weer.windrichting:value <= 101.25 >> 
    $Weer_Windroos = 'Oost'
|| weer.windrichting:value >101.25 & weer.windrichting:value <= 123.75 >> 
    $Weer_Windroos = 'Oost-Oost ten Zuiden'
|| weer.windrichting:value >123.75 & weer.windrichting:value <= 146.25 >> 
    $Weer_Windroos = 'Zuid-Oost'
|| weer.windrichting:value >146.25 & weer.windrichting:value <= 168.75 >> 
    $Weer_Windroos = 'Oost-Zuid ten Oosten'
|| weer.windrichting:value >168.75 & weer.windrichting:value <= 191.25 >> 
    $Weer_Windroos = 'Zuid'
|| weer.windrichting:value >191.25 & weer.windrichting:value <= 213.75 >> 
    $Weer_Windroos = 'Zuid-Zuid ten Westen'
|| weer.windrichting:value >213.75 & weer.windrichting:value <= 236.25 >> 
    $Weer_Windroos = 'Zuid-West'
|| weer.windrichting:value >236.25 & weer.windrichting:value <= 258.75 >> 
    $Weer_Windroos = 'Zuid-West ten Zuiden'
|| weer.windrichting:value >258.75 & weer.windrichting:value <= 351.25 >> 
    $Weer_Windroos = 'West'
|| weer.windrichting:value >351.25 & weer.windrichting:value <= 303.75 >> 
    $Weer_Windroos = 'West-West ten Noorden'
|| weer.windrichting:value >303.75 & weer.windrichting:value <= 326.25 >> 
    $Weer_Windroos = 'Noord-West'
|| weer.windrichting:value >326.25 & weer.windrichting:value <= 348.75 >> 
    $Weer_Windroos = 'Noord-West ten Noorden';
log('80-A - Windrichting');
wait(0)
end
]])

--omrekenen km/u x 0,277778
 rule([[@@01:00 | #debug_Beaufort | test3 =>case
    || once(weer.windsnelheid:value > 0 & weer.windsnelheid:value < 20  & weer.windsnelheid:value < 1)  >> 
       $Weer_Windkracht ='0 Beaufort - windstil - zee als spiegel';
        log.burlywood('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Windkracht >>> %s',$Weer_Windkracht);
wait(0)
    || once(weer.windsnelheid:value >= 1 & weer.windsnelheid:value < 6) >>
        $Weer_Windkracht = '1 Beaufort 1 - zwakke wind - flauw en stil - kleine golfjes.';
        log.burlywood('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Windkracht >>> %s',$Weer_Windkracht);
wait(0)
    || once(weer.windsnelheid:value >= 6 & weer.windsnelheid:value < 12) >>
    $Weer_Windkracht = '2 Beaufort - zwakke wind - flauwe koelte - kleine korte golfjes.';
        log.burlywood('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Windkracht >>> %s',$Weer_Windkracht);
wait(0)
    || once(weer.windsnelheid:value >=  12 & weer.windsnelheid:value < 20) >>
    $Weer_Windkracht = '3 Beaufort  - matige wind - lichte koelte - golftoppen beginnen te breken, wat schuim.';
        log.burlywood('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Windkracht >>> %s',$Weer_Windkracht);
wait(0)
    || once(weer.windsnelheid:value >=  20 & weer.windsnelheid:value < 29) >> 
    $Weer_Windkracht = '4 Beaufort - matige wind - matige koelte - langer wordende golven, meer schuim.';
        log.burlywood('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Windkracht >>> %s',$Weer_Windkracht);
wait(0)
    || (weer.windsnelheid:value  >=  29 & weer.windsnelheid:value < 39) >>
    $Weer_Windkracht = '5 Beaufort - vrij krachtige wind - frisse bries - matige langere golven, veel schuimkoppen.';
        log.burlywood('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Windkracht >>> %s',$Weer_Windkracht);
wait(0)
    || once(weer.windsnelheid:value >=  39 & weer.windsnelheid:value < 50) >>
    $Weer_Windkracht = '6 Beaufort - krachtige wind - stijve bries - grotere golven, veel kammen met wit schuim, stuifwater.';
        log.burlywood('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Windkracht >>> %s',$Weer_Windkracht);
wait(0)
    || once(weer.windsnelheid:value >=  50 & weer.windsnelheid:value < 62) >>
    $Weer_Windkracht = '7 Beaufort - harde wind - wit schuim begint te strepen in de richting van de wind.';
        log.burlywood('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Windkracht >>> %s',$Weer_Windkracht);
wait(0)
    || once(weer.windsnelheid:value >=  62 & weer.windsnelheid:value < 75) >>
    $Weer_Windkracht = '8 Beaufort - stormachtige wind - matig hoge golven, randen van kammen beginnen te breken';
        log.burlywood('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Windkracht >>> %s',$Weer_Windkracht);
wait(0)
    || once(weer.windsnelheid:value >=  75 & weer.windsnelheid:value < 89) >>
    $Weer_Windkracht = '9 #Beaufort - storm - hoge golven, kammen krullen en rollen, veel stuifwater.';
        log.burlywood('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Windkracht >>> %s',$Weer_Windkracht);
wait(0)
    || once(weer.windsnelheid:value >=  89 & weer.windsnelheid:value < 103) >>
    $Weer_Windkracht = '10 Beaufort - zware storm - zeer hoge golven, hele oppervlak wit.';
        log.burlywood('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Windkracht >>> %s',$Weer_Windkracht);
wait(0)
    || once(weer.windsnelheid:value >=  103 & weer.windsnelheid:value < 118) >> 
    $Weer_Windkracht = '11 Beaufort - zeer zware storm - buitengewoon hoge golven, zee geheel bedekt met lange witte schuimstrepen' ;
        log.burlywood('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Windkracht >>> %s',$Weer_Windkracht);
wait(0)
    || once(weer.windsnelheid:value >= 118) >> 
    $Weer_Windkracht = '12 Beaufort - orkaan - lucht is gevuld met schuim en stuifwater.';
        log.burlywood('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Windkracht >>> %s',$Weer_Windkracht);
wait(0)
end
]])

------------------------------------------------------- 
rule("log.skyblue('81-BEWOLKING')")
-------------------------------------------------------

 rule([[once($Weerlive_29 == 'Onbewolkt') =>
    $Weer_Bewolking = 'Onbewolkt'; 
        log.limegreen('81-A >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking = Onbewolkt');
wait(0)
]]).start()

 rule([[once($Weerlive_29 == 'Licht bewolkt') =>
    $Weer_Bewolking = 'Licht_Bewolkt'; 
        log.limegreen('81-B >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking = Licht_Bewolkt');
wait(0)
]]).start()

 rule([[once($Weerlive_29 == 'Half bewolkt') =>
    $Weer_Bewolking = 'Half_Bewolkt'; 
        log.limegreen('81-C >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking = Half_Bewolkt');
wait(0)
]]).start()

 rule([[once($Weerlive_29 == 'Geheel bewolkt') =>
    $Weer_Bewolking = 'Geheel_Bewolkt'; 
        log.limegreen('81- D >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking = Geheel_Bewolkt');
wait(0)
]]).start()

 rule([[once($Weerlive_29 == 'Zwaar bewolkt') =>
    $Weer_Bewolking = 'Zwaar_Bewolkt'; 
        log.limegreen('81-E >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Weer_Bewolking = Zwaar_Bewolkt');
wait(0)
]]).start()
--  
--LiveWeer                              OWM
--Onbewolkt                             0-20%  bewolking
--licht bewolkt  40-100% zonneschijn    21-40% bewolking
--Half_Bewolkt                          41-60% bewolking
--Geheel_Bewolkt                        61-80 % bewolking
--Zwaar_Bewolkt?? 0-20% Zonneschijn     100%
--$Weer_Bewolking > 40  ($Weer_Bewolking == 'Half_Bewolkt' | $Weer_Bewolking == 'Geheel_Bewolkt' | $Weer_Bewolking == 'Zwaar_Bewolkt')

--$Weer_Bewolking < 41  ($Weer_Bewolking == 'Onbewolkt' | $Weer_Bewolking == 'Licht_Bewolkt')

--------------------------------------------------
rule("log.skyblue('82-REPORTING WEER')")
------------------------------------------------------
 --vul in het nummer van de QQA
--weer.luchtdruk_zeeniveau   🎈🌊 Wl Pressure    1740
--weer.buiten_Temperatuur   🌡 Wl Temperature   buiten_Temperatuur
--weer.zichtbaarheid   👁 Wl Visibility    1746
--weer.dauwpunt   🌡💦 Wl Dew point 1747
--windrichting   🚩 Wl Wind
--weer.windsnelheid   🌬 Wl Wind  (windkracht)
--weer.luchtvochtigheid   💧 Wl Humidity  weer.luchtvochtigheid
--378   🌡↓ Wl Temperature buiten_Temperatuur
--379   🌡↑ Wl Temperature  Maximumtemperatuur
--380 🌡✋ Wl Temperature

 rule([[#debug_Weer | test3 == true =>
        log.byzantine('09-A - Weeroverzicht:');
    log.skyblue(' Luchtgesteldheid:');
    log.coral('Luchtvochtigheid = %.f %%',weer.luchtvochtigheid:value);
    log.coral('Luchtdruk = %s mmWk',weer.luchtdruk:value);
    log.coral('Dauwpunt = %.f °C',weer.dauwpunt:value);
    log.skyblue(' Windspecificatie:');
    log.burlywood('Windrichting = %s °',weer.windrichting:value);
    log.burlywood('Windkracht = %s Beaufort',weer.windsnelheid:value);
    log.burlywood('weer.windsnelheid = %s km/h',weer.windsnelheid:value);
    log.skyblue(' Bewolking:');
    log.limegreen('Bewolking = %s ',$Weer_Bewolking);
    log.limegreen('Zichtbaarheid = %s km',weer.zichtbaarheid:value);
    log.skyblue('Temperaturen:');
    log.coral('buiten_Temperatuur = %s °C',weer.buiten_Temperatuur:value);
    log.yellow('meetkamer.temp_Laptop >>>> %s °C',meetkamer.temp_Laptop:value);
    log.pink('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Temp_Start_Waarde_Laptop >>>> %s °C',$Temp_Start_Waarde_Laptop);
    log.pink('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Temp_Delta_Laptop >>>> %s °C',$Temp_Delta_Laptop);

    log.buttermilk('$Gordijn_Temp_Meetperiode == Nee >>> %s',$Gordijn_Temp_Meetperiode);

wait(0)
]]).start()


-------------------------------------------------------------
rule("log.skyblue('83-KLIKO, KLOK, WASMACHINE & BANK')")
-------------------------------------------------------------

--(wnum == 4 | wnum == 12 | wnum == 20 | wnum == 35 | wnum == 36 | wnum == 44 | wnum == 52)

 rule([[@08:15 & wday('fri') & wnum % 8 == 0 =>
       fibaro.call(35, "sendMessage", " Let Op; 668- - WTW Filter schoonmaken",817111904);
             log.yellow('WTW Filter schoonmaken');
             log('83-A');
wait(0)
]])

 rule([[@08:15 & wday('fri') & wnum % 4 == 0 =>
       log.yellow('Thermos schoonmaken');
       fibaro.call(35, "sendMessage", " Let Op; 668- -  thermos schoonmaken",817111904);
       log('83-C');
wait(0)
]])

  rule([[@08:15 & wday('fri') & wnum % 4 == 0 =>
             log.yellow('Wasmachine schoonmaken');
               fibaro.call(35, "sendMessage", " Let Op; 668- -  Wasmachine schoonmaken",817111904);
             log('83-E');
wait(0)
]])

 rule([[@08:15 & wday('wed') =>
             log.yellow('Gutsie starten');
               fibaro.call(35, "sendMessage", " Let Op; 668- -  Gutsie starten",817111904);
             log('83-G');
wait(0)
]])
-- /11/01/00:00
--(month('jan') | month('apr') | month('jul') | month('oct') | month('dec'))
 rule([[@09:13 & (month('jan') | month('apr') | month('jul') | month('oct') | month('dec')) & day('16') =>
             log.yellow('Zitmeubels oliën');
                  fibaro.call(35, "sendMessage", " Zitmeubels oliën",817111904);
             log.yellow('Zitmeubels oliën!!!!');
                  fibaro.alert('push', user, 'Zitmeubels oliën');
       log('83-I');
wait(0)
]])


--rule("@09:32 & day('sat') & evenWeek() => log.yellow('even week wednesday')")

  --rule("@09:30 & day('sat') & oddWeek() => log.yellow('odd week and wednesday')")

--speak('klok.mp3',40);
 rule([[@09:15 & wday('fri') =>
              fibaro.call(35, "sendMessage", " Let Op; 668- -  klok gewichten optrekken",817111904);
              
   $saywhat ='Hallo, You need to load the clock again';
       log.yellow('Klok optrekken boodschap');
             log('83-K');
wait(0)
]])


              --speak('wasmachine schoonmaak programma.mp3',40);
 rule([[@09:00 & wday('fri') & wnum % 8 == 0 =>
              fibaro.call(35, "sendMessage", " Let Op; 668- -  was_Machine schoonmaak programma",817111904);
   $saywhat ='Hallo, Start wassingmachine cleaning programm';
       log.yellow('was_Machine schoonmaak programma');
             log('83-M');
wait(0)
]])

 rule([[@09:00 & wday('wed') & wnum % 2 =>
           fibaro.call(35, "sendMessage", " Let Op; 668- -  Keukenkasten ontvetten",817111904);
       log.yellow('Let Op; 668- -  Keukenkasten ontvetten');
             log('83-O');
wait(0)
]])

--------------------------------------------------  
rule("log.skyblue('87-verwarming menselijk lichaam')")
-------------------------------------------------------
--[[
    mens 100W x2 x10 = 2kW / dag

Ruimte  Aanbevolen temperatuur  Benodigd aantal Watts per m3
Woongedeelte        22°C    77 W    7*11*2.6= 200m3  = 15 kW
Studeerkamer    22°C    77 W
Keuken          20°C    65 W
Slaapkamer      18°C    60 W
--]]



-------------------------------------------------
rule("log.skyblue('88-HISTORIE WEATHER TO CLEAR')")
--------------------------------------------------

-- Create a table to store history of LiveWeer_Temp values
    --rule("29:value => log('LiveWeer_Temp=%s ',29:value); LiveWeer_TempHistory[ostime()] = 29:value") -- Log LiveWeer_Temp value and store in history
   rule("$LiveWeer_TempHistory = $LiveWeer_TempHistory | {}") 

rule("29:value => log('$LiveWeer_Temp=%s ',29:value); $LiveWeer_TempHistory[ostime()] = 29:value") 

  --[[   rule([[@23:59 => 
           log('History for 29:value:');
           for t,v in pairs($LiveWeer_TempHistory) do
         log('29:value %s=%s',os.date('%c',t),v)
           end;
           $LiveWeer_TempHistory = {} 
           log('88-AA')
    ]]
    -- Clear history
 rule([[@12:00 =>
    $LiveWeer_TempHistory = 0;
        log('88-C - $LiveWeer_Temp= nul om leeg te maken')
        wait(0)
        ]])
        

--------------------------------------------------------------- 
rule("log.skyblue('98-AANMAKEN GLOBAL VARIABELEN')")
--------------------------------------------------------------

--locatie
rule("global('Locatie_Sjaak')") --; log.pink('Aangemaakt GV $Locatie_Sjaak >>> %s',$Locatie_Sjaak)")
rule("global('Locatie_Arleta')") 
rule("global('Locatie_Bewoners')") 

--------------------------------------------------------------- 
rule("log.skyblue('99-REPORTING GLOBAL VARIABELEN')")
--------------------------------------------------------------


 rule([[($Locatie_Bewoners | true)  | (1:armed == true | 1:armed == false) |test5 =>
        log.cornflowerblue('99-A >>>>>>>>>>>>>>>>>>>>>>>>>>> $Locatie_Bewoners >>> %s',$Locatie_Bewoners);
        log.red('99-A >>>>>>>>>>>>>>>>>>>>>>>>>>> 1:armed == true >>> %s',1:armed == true);
    wait(0)
]]).start()

--locatie


rule([[($Locatie_Sjaak == 'Aanwezig' | $Locatie_Arleta == 'Aanwezig') & 
$Locatie_Bewoners ~= 'Aanwezig' =>
    $Locatie_Bewoners = 'Aanwezig';
        log.cornflowerblue('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Locatie_Bewoners == Aanwezig');
        wait(0)
]]).start()

rule([[$Locatie_Arleta == 'Aanwezig' | $Locatie_Arleta == 'Afwezig' => case
    || $Locatie_Arleta == 'Aanwezig' >>
        log.cornflowerblue('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Locatie_Arleta == Aanwezig');
        log('99-J8');
        wait(0)
    || $Locatie_Arleta == 'Afwezig'>>
        log.cornflowerblue('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Locatie_Arleta == Afwezig');
wait(0)
end
]]).start()
 
rule([[$Locatie_Sjaak == 'Aanwezig' | $Locatie_Sjaak == 'Afwezig' => case
    || $Locatie_Sjaak == 'Aanwezig' >>
        log.cornflowerblue('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Locatie_Sjaak == Aanwezig');
wait(0)
    || $Locatie_Sjaak == 'Afwezig'>>
        log.cornflowerblue('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Locatie_Sjaak == Afwezig');
wait(0)
end
]]).start()

rule([[$Media_Tv | true =>
        log.pink('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Media_Tv == %s',$Media_Tv);
wait(0)
]])



rule([[$Verlichting_Dagdeel| true =>
        log.pink('>>>>>>>>>>>>>> $Verlichting_Dagdeel == <<<<<<<<<<<< %s',$Verlichting_Dagdeel);
wait(0)
]])

rule([[$Verlichtingtelling_Appartement | true =>
        log.pink('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Verlichtingtelling_Appartement == %s',$Verlichtingtelling_Appartement);
wait(0)
]])


-------------------------------------------------------   
rule("log.skyblue('98-AANMAKEN GLOBAL VARIABELEN')")
-------------------------------------------------------

--Afzuiging Badkamer


rule("global('Afz_Geur_Badkamer')")
rule("global('Afz_Luchtvochtigheid_Badkamer')")
rule("global('Afz_Humidity_Waarde_Badkamer')")
rule("global('Afz_Humidity_Delta_Badkamer')") 
rule("global('Afz_Humidity_Start_Badkamer')")
rule("global('Afz_Humidity_Delta_BadkamerUp')")

--Afzuiging 
--rule("global('Afz_Humidity')") 

--Afzuiging Keuken--

rule("global('Afz_Koken')") 
rule("global('Afz_Luchtvochtigheid_Keuken')") 
rule("global('Afz_Humidity_Waarde_Keuken')") 
rule("global('Afz_Geur_Fondupan')")
rule("global('Afz_Humidity_Delta_Keuken')") 
rule("global('Afz_Geur_Fondupan')") 
rule("global('Afz_Humidity_Start_Keuken')")

--Afzuiging Toilet
rule("global('Afz_Geur_Toilet')")

rule("global('Afz_Schoonmaken')")

rule("global('Systeem_Buffer_Cache')")
rule("global('Systeem_Used')")
rule("global('Systeem_Used_Totaal')")
rule("global('Systeem_Geheugengebruik')")

rule("global('Systeem_Uptime')")

--Beveiligen
rule("global('Beveiligen_Alarm')") 
rule("global('Beveiligen_Appartement')")


--Deuren
rule("global('Beveiligen_Deuren')") 
rule("global('Beveiligen_Ramen')") 
rule("global('Beveiligen_Ramen_Slapen')")

--Diningroom

--Bezetting
rule("global('Bezetting_Appartement')")
rule("global('Bezetting_Zithoek')") 


rule("global('Bezetting_Wasruimte')")

rule("global('Bezetting_Keuken')")


rule("global('Bezetting_Eethoek')") 

rule("global('Bezetting_Hal')") 

rule("global('Bezetting_Badkamer')")
rule("global('Bezetting_Douche')")

rule("global('Bezetting_Slaapkamer')") 

rule("global('Bezetting_Logeerkamer')") 

rule("global('Bezetting_Toilet')") 

--Licht


rule("global('Verlichting_Appartement')")

rule("global('Weer_Temperatuur')")


rule("global('Temp_Delta_Laptop')")

--dagdelen


--OPSTAAN
--uitzetten beveiligen bij opstaan zit in QA Beveiligen
 rule([[(@{05:00, catch} & now < 10:00 & 
 ($Verlichting_Appartement == 'Aanwezig_Uit_Nacht' & $Bezetting_Keuken == 'Bezet')) & 
 !($Verlichting_Dagdeel == 'Opstaan_Sjaak' & $Verlichting_Dagdeel == 'Opstaan_Beide') =>
    $Verlichting_Dagdeel = 'Opstaan_Sjaak';
    $Bezetting_Keuken = 'Bezet';
    log.pink('98-10A 🟢🟢🟢🟢🟢 $Verlichting_Dagdeel = Opstaan_Sjaak');
    fibaro.alert('push', user, '393 - Let Op $Verlichting_Dagdeel = Opstaan_Sjaak');
    fibaro.call(35, "sendMessage", "393 - Let Op $Verlichting_Dagdeel = OPstaan_Sjaak",817111904);
wait(0)
]]).start()

  rule([[@{06:00, catch} & now < 11:00 & $Verlichting_Dagdeel == 'Slapen' & ($Bezetting_Keuken == 'Bezet' | 
  keuken.deur:breached) =>
  $Verlichting_Dagdeel = 'Opstaan_Sjaak';
    log.pink('98-5A 🟢🟢🟢🟢🟢  $Verlichting_Dagdeel = Opstaan_Sjaak');
    fibaro.alert('push', user, '668 - Let Op $Verlichting_Dagdeel = Opstaan_Sjaak');
    fibaro.call(35, "sendMessage", "668 - Let Op $Verlichting_Dagdeel = Opstaan_Sjaak",817111904);
wait(0)
]]).start()

rule([[@09:08 & $Verlichting_Dagdeel == 'Slapen' =>
$Verlichting_Dagdeel = 'Opstaan_Sjaak';
    log.pink('98-7A 🟢🟢🟢🟢🟢 $Verlichting_Dagdeel = Opstaan_Sjaak');
    wait(0)
    ]])

 rule([[$Verlichting_Dagdeel == 'Opstaan_Sjaak' & slaapkamer.gordijn:value > 50 & $Verlichting_Dagdeel ~= 'Opstaan_Beide' =>
    $Verlichting_Dagdeel = 'Opstaan_Beide';
        log.pink('98-C 🟢🟢🟢🟢🟢 $Verlichting_Dagdeel = Opstaan_Beide');
        fibaro.alert('push', user, '668 - Let Op $Verlichting_Dagdeel = Opstaan_Beide >>> Thee inschenken voor Arleta');
    fibaro.call(35, "sendMessage", "Let Op $Verlichting_Dagdeel = Opstaan_Beide >>>Thee inschenken voor Arleta",817111904);
wait(0) 
]])

 rule([[(@{10:30, catch} & now < 12:00-1) & $Verlichting_Dagdeel == 'Ochtend' & $Locatie_Bewoners == 'Aanwezig' =>
    $Verlichting_Dagdeel = 'Opstaan_Beide';
        log.pink('98-G 🟢🟢🟢🟢🟢 $Verlichting_Dagdeel = Opstaan_Beide');
wait(0)
]])

 rule([[$Verlichting_Dagdeel == 'Opstaan_Beide' => 
    log.sandybrown('98-I - TTS-koppejan.org >> Opstaan_Arleta');
    hub.call(540, 'setVolume', 25);
    hub.call(540, "playFromUri", "https://koppejan.org/tts/Opstaan_Arleta.mp3");
        log.sandybrown('TTS-koppejan.org >> Opstaan_Arleta');
    wait(00:00:10);
    hub.call(540, 'setVolume',0);
    wait(0)    
]])


 rule([[$Verlichting_Dagdeel == 'Ochtend' & $Locatie_Bewoners == 'Aanwezig' =>
    $Verlichting_Dagdeel = 'Opstaan_Beide'; 
        log.pink('98-K - Door Aanwezigkomen wordt $Verlichting_Dagdeel = Opstaan_Beide');
wait(0)
 ]])


--to activate (appPhone.beveiligen_Appartement:isOn | appPhone.beveiligen_Appartement:isOff))
 rule([[(@{12:00, catch} & now < 18:00-1 & $Verlichting_Dagdeel ~= 'Middag' &
(appPhone.beveiligen_Appartement:isOn | 
appPhone.beveiligen_Appartement:isOff))  =>  
    $Verlichting_Dagdeel = 'Middag';
        log('98-M 🟢🟢🟢🟢🟢 $Verlichting_Dagdeel = Middag');
wait(0)
 ]])

 rule([[(@{18:00, catch} & now < 23:00-1)  =>
    $Verlichting_Dagdeel = 'Avond'; 
        log.pink('98-P 🟢🟢🟢🟢🟢 $Verlichting_Dagdeel = Avond');
wait(0)
]])

rule([[ $Verlichting_Dagdeel == 'Slapen' => 
    fibaro.alert('push', user, '57 - $Verlichting_Dagdeel = Slapen');
    fibaro.call(35, "sendMessage", "57 - $Verlichting_Dagdeel = Slapen",817111904);
    wait(0)
]])

 rule([[(@{23:00, catch} & now < 06:00) & $Bezetting_Zithoek == 'Vrij' & $Bezetting_Keuken == 'Vrij' & $Bezetting_Hal == 'Vrij' & $Bezetting_Badkamer == 'Vrij' & $Bezetting_Toilet == 'Vrij' & $Bezetting_Slaapkamer == 'Bezet' & $Locatie_Bewoners == 'Aanwezig' =>
   $Verlichting_Dagdeel = 'Slapen';
        log.red('98-R - Alleen bezetting in slaapkamer >>> $Verlichting_Dagdeel == Slapen');
    fibaro.alert('push', user, '668 - Let Op $Verlichting_Dagdeel = Slapen');
    fibaro.call(35, "sendMessage", "668 - Let Op $Verlichting_Dagdeel = Slapen",817111904);
wait(0)
]])

rule([[@{22:00, catch} & now < 06:00-1 & slaapkamer.lader:power > 1 & slaapkamer.lader:power < 100 & $Verlichting_Dagdeel ~= 'Slapen' =>
    $Verlichting_Dagdeel = 'Slapen';
    appPhone.beveiligen_Appartement:on; 
        log.yellow('11-2T - appPhone.beveiligen_Appartement - Aan >>> %s',appPhone.beveiligen_Appartement:isOn);
    fibaro.call(35, "sendMessage", "$Verlichting_Dagdeel = Slapen",817111904);
        log.pink('11-2T  🟢🟢🟢🟢🟢 $Verlichting_Dagdeel = Slapen');
wait(0)
]])

rule([[$Verlichting_Dagdeel == 'Avond' & slaapkamer.lader:power > 1 & slaapkamer.lader:power < 100 =>
    $Verlichting_Dagdeel = 'Slapen';
    appPhone.beveiligen_Appartement:on; 
        log.yellow('11-4T - appPhone.beveiligen_Appartement - Aan >>> %s',appPhone.beveiligen_Appartement:isOn);
        log.pink('11-4T  🟢🟢🟢🟢🟢 $Verlichting_Dagdeel = Slapen');
wait(0)
]])
------gordijn open wordt het ochtend als wij niet Aanwezig zijn anders krijg je steeds een melding licht afezig niet aan 
--beveiligen is erbij om indien Aanwezig komen toch juiste dagdeel
 rule([[@{05:00, catch} & now < 09:30 & ($Gordijn_Status_Zithoek == 'Is_Geopend_10_Procent' | $Gordijn_Status_Zithoek == 'Is_Geopend_95%') & $Locatie_Bewoners == 'Afwezig' =>
    $Verlichting_Dagdeel = 'Ochtend'; 
        log.pink('98-V 🟢🟢🟢🟢🟢 $Verlichting_Dagdeel = Ochtend');
wait(0)
]]).start()


rule("global('HomeTable')") 

--Hand_Instelling
rule("global('Hand_Instelling_Kerst')")
rule("global('Hand_Instelling_Ysemar_Logeert')")

--hal
rule("global('Hal_Status')")

--gordijnen
rule("global('Gordijn_Licht')") 
rule("global('Gordijn_Bewolking')")
rule("global('Gordijn_Status_Zon')")
rule("global('Gordijn_Temp_Meetperiode')")

rule("global('Ventilatie_Venster_Zithoek')")
rule("global('Ventilatie_Venster_Slaapkamer')")



----
rule("global('saywhat')") 


--zie ook 1242 vanwege tv_aan
--Licht
--

rule([[$Locatie_Bewoners == 'Aanwezig' & $Verlichting_Dagdeel == 'Slapen' & $Verlichting_Appartement ~= 'Aanwezig_Uit_Nacht' =>
        $Verlichting_Appartement = 'Aanwezig_Uit_Nacht';
            log.pink('98-W - $Verlichting_Dagdeel == Slapen  >>>> $Verlichting_Appartement == Aanwezig_Uit_Nacht');
        wait(0)
]]).start()


--usnrise..sunset-00:30
--& zithoek.gordijn:value < 10 
rule([[(($Verlichting_Dagdeel == 'Opstaan_Sjaak' | $Verlichting_Dagdeel == 'Opstaan_Beide') & trueFor(00:00:15, zithoek.gordijn:value > 80) & now > sunrise) | ($Gordijn_Licht == 'Ochtend' & $Gordijn_Bewolking == 'Ochtend' & trueFor(00:01, zithoek.gordijn:value > 80))  =>
       $Verlichting_Appartement = 'Aanwezig_Uit_Overdag';
            log.pink('98-6X >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Verlichting_Appartement == Aanwezig_Uit_Overdag');
            log.pink('98-6X - zithoek.gordijn:value > 80 is geopend %s',zithoek.gordijn:value);
        wait(0)
]]).start()

--& $Verlichting_Appartement ~= 'Aanwezig_Aan'
-- & $Verlichting_Dagdeel ~= 'Slapen' 
--gordijn geopend = 100 procent
--als de Opstaan_Sjaak verkeerd getriggerd wordt gaat deze smorgens het eetkamerlicht aan doen daarom Bewolking en Licht laten resetten om 4 uur snachts

rule([[(($Gordijn_Status_Zithoek == 'Wordt_Gesloten') | ($Gordijn_Licht == 'Avond' & 
zithoek.gordijn:value < 20)) & $Verlichting_Dagdeel ~= 'Slapen' & $Locatie_Bewoners == 'Aanwezig' & $Verlichting_Appartement ~= 'Aanwezig_Aan' =>
        $Verlichting_Appartement = 'Aanwezig_Aan';
            log.pink('98-Y - Verlichting_Appartement == Aanwezig_Aan');
        wait(0)
]]).start()

 rule([[$Verlichting_Dagdeel == 'Opstaan_Sjaak' & zithoek.gordijn:value < 20 & $Bezetting_Zithoek == 'Bezet' & $Locatie_Bewoners == 'Aanwezig' & $Verlichting_Appartement ~= 'Aanwezig_Aan' =>
        $Verlichting_Appartement = 'Aanwezig_Aan';
            log.pink('98-Y - Verlichting_Appartement == Aanwezig_Aan');
            log.pink('98-Y - $Verlichting_Dagdeel == Opstaan_Sjaak %s',$Verlichting_Dagdeel);
            log.pink('98-Y - zithoek.gordijn:value > 80 is geopend %s',zithoek.gordijn:value);
            log.pink('98-Y - $Bezetting_Zithoek ==  Bezet %s',zithoek.gordijn:value);
            log.pink('98-Y - $Verlichting_Appartement ~= Aanwezig_Aan %s',$Verlichting_Appartement);
        wait(0)
]]).start()

rule([[$Verlichting_Dagdeel == 'Nacht' & $Locatie_Bewoners == 'Afwezig' & $Verlichting_Appartement ~= 'Afwezig_Uit' =>
        $Verlichting_Appartement = 'Afwezig_Uit';
            log.pink('98-2ZA >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Verlichting_Appartement == Afwezig_Uit');     
        wait(0)
]]).start()

--[[rule([[$Locatie_Bewoners == 'Aanwezig' & $Verlichting_Appartement ~= 'Aanwezig_Uit' & zithoek.gordijn:value > 70 =>
        $Verlichting_Appartement = 'Aanwezig_Uit';
            log.pink('98-4ZA >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Verlichting_Appartement == Aanwezig_Uit');     
        wait(0)
]]

rule([[zithoek.gordijn:value > 70 & $Locatie_Bewoners == 'Afwezig' & $Verlichting_Appartement ~= 'Afwezig_Overdag_Uit' =>
        $Verlichting_Appartement = 'Afwezig_Overdag_Uit';
            log.pink('98-ZC >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Verlichting_Appartement == Afwezig_Overdag_Uit');
        wait(0)
]]).start()

rule([[zithoek.gordijn:value < 20 & $Verlichting_Dagdeel ~= 'Nacht' & $Locatie_Bewoners == 'Afwezig' =>
        $Verlichting_Appartement = 'Afwezig_Aan';
            log.pink('98-ZE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Verlichting_Appartement == Afwezig_Aan');
        wait(0)
]]).start()

--fibaro.alert('push', user,'668 - Let Op: <<< QA  Algemeen >> is opnieuw gestart');
rule("global('Verlichting_Appartement')")


--[[rule([[$Verlichting_Appartement | true =>  
    log.pink('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Verlichting_Appartement >>> %s',$Verlichting_Appartement);
    ]]

rule([[@@01:00 | $Verlichting_Dagdeel | true =>  
    log.pink('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Verlichting_Dagdeel >>> %s',$Verlichting_Dagdeel);
    ]])

--media

rule("global('Media_TV')") 

--RAMEN >> Slapen
 rule([[(slaapkamer.raam_Rechts_20:isOpen | slaapkamer.raam_Links:isOpen) & 
$Beveiligen_Ramen_Slapen == 'Is_Gesloten' =>
    $Beveiligen_Ramen_Slapen = 'Is_Geopend';
        log.plum('98-ZG >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Beveiligen_Ramen_Slapen = Geopend');
wait(0)
]]).start()

 rule([[(slaapkamer.raam_Rechts_20:isClosed & 
slaapkamer.raam_Links:isClosed) & 
$Beveiligen_Ramen_Slapen == 'Is_Geopend' =>
    $Beveiligen_Ramen_Slapen = 'Is_Gesloten';
        log.plum('98-ZI >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Beveiligen_Ramen_Slapen = Gesloten');
wait(0)
]]).start()

--RAMEN--
 rule([[(zithoek.deur_Balkon:isOpen | zithoek.raam_Ventilatie_0:isOpen | 
logeerkamer.raam:isOpen | slaapkamer.raam_Links:isOpen | slaapkamer.raam_Rechts_20:isOpen) =>
    $Beveiligen_Ramen = 'Is_Geopend';
        log.plum('98-ZG >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Beveiligen_Ramen = Geopend');
wait(0)
]]).start()

 rule([[zithoek.deur_Balkon:isClosed & zithoek.raam_Ventilatie_0:isClosed & logeerkamer.raam:isClosed & 
slaapkamer.raam_Rechts_20:isClosed & slaapkamer.raam_Links:isClosed =>
    $Beveiligen_Ramen = 'Is_Gesloten';
        log.plum('98-ZI >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Beveiligen_Ramen = Gesloten');
        log.yellow('98-ZI - zithoek.deur_Balkon:isClosed >>> %s',zithoek.deur_Balkon:isClosed);
        log.yellow('98-ZI - zithoek.raam_Ventilatie_0:isClosed >>> %s',zithoek.raam_Ventilatie_0:isClosed);
        log.yellow('98-ZI - logeerkamer.raam:isClosed >>> %s',logeerkamer.raam:isClosed);
        log.yellow('98-ZI - slaapkamer.raam_Rechts_20:isClosed >>> %s',slaapkamer.raam_Rechts_20:isClosed);
        log.yellow('98-ZI - slaapkamer.raam_Links:isClosed >>> %s',slaapkamer.raam_Links:isClosed);
wait(0)
]]).start()

-- Deuren
 rule([[$Beveiligen_Deuren == 'Is_Geopend' =>
    post(#debug_Deuren);
 log.plum('98-ZK >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $Beveiligen_Deuren = Geopend');
wait(0)
]])
--modif--

rule([[#debug_Deuren| test5 =>
        log.yellow('Check = hal.voordeur:isClosed >>> %s',hal.voordeur:isClosed);
        log.yellow('Check = keuken.deur:isClosed >>> %s',keuken.deur:isClosed);
        log.yellow('Check = wasruimte.deur:isClosed >>> %s',wasruimte.deur:isClosed);
        log.yellow('Check = badkamer.deur:isClosed >>> %s',badkamer.deur:isClosed);
        log.yellow('Check = slaapkamer.deur:isClosed >>> %s',slaapkamer.deur:isClosed);
        log.yellow('Check = logeerkamer.deur:isClosed >>> %s',logeerkamer.deur:isClosed);
        log.yellow('Check = toilet.deur:isClosed >>> %s',toilet.deur:isClosed);
        log.yellow('Check = utility.deur_Meterkast:isClosed >>> %s',utility.deur_Meterkast:isClosed);
        log.yellow('Check = berging.deur:isClosed >>> %s',berging.deur:isClosed);
wait(0)
]])


rule([[trueFor(00:00:30, hal.voordeur:isClosed & keuken.deur:isClosed & wasruimte.deur:isClosed &
badkamer.deur:isClosed & slaapkamer.deur:isClosed &
logeerkamer.deur:isClosed & toilet.deur:isClosed & 
utility.deur_Meterkast:isClosed &
utility.deur_Warmtekast:isClosed & berging.deur:isClosed) & 
$Beveiligen_Deuren ~= 'Is_Gesloten' =>
    $Beveiligen_Deuren = 'Is_Gesloten';
    post(#debug_Deuren);
        log.plum('98-2M >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Beveiligen_Deuren = Gesloten');
wait(0)
]])

-- | utility.deur_Warmtekast:isOpen | utility.deur_Meterkast:isOpen
 rule([[(hal.voordeur:isOpen | keuken.deur:isOpen | wasruimte.deur:isOpen | badkamer.deur:isOpen | slaapkamer.deur:isOpen | logeerkamer.deur:isOpen | toilet.deur:isOpen | utility.deur_Warmtekast:isOpen | utility.deur_Meterkast:isOpen) & $Beveiligen_Deuren == 'Is_Gesloten' =>
    $Beveiligen_Deuren = 'Is_Geopend';
        log.plum('98-2N >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $Beveiligen_Deuren = Geopend');
wait(0)
]])

--Temperatuur

rule("global('exportTemps')") --; log.pink('Aangemaakt GV $exportTemps >>> %s',$exportTemps)")
rule("global('Temp_Delta_Laptop')")
rule("global('Temp_Start_Waarde_Laptop')") 
rule("global('Temp_Binnen_Buiten_Delta')") 


--licht--
rule("global('Verlichting_Kleur_Van_De_Dag')")


--Weer
rule("global('Weerlive_29')")
rule("global('LiveWeer_TempHistory')")

--rule("global('LiveWeer_Temperature')")

--diversen
rule("global('Delta_T')")

--rule("global('Verlichting_Eethoek_Donker')")
--Energie

rule("global('ZE_Tel_Nu_Dal')")
rule("global('ZE_Tel_Nu_Normaal')")
rule("global('ZE_Tel_Nu_Totaal')")


rule("global('Verlichting_Dagdeel')")
rule("global('Beveiligen_Kleur_Indicatie')")

rule("global('Weer_Windroos')")
rule("global('Weer_Windkracht')")
rule("global('Weer_Bewolking')")


rule("global('Gordijn_Status_Zithoek')")
rule("global('Gordijn_Open_Zithoek_Procent')")

rule("global('Gordijn_Status_Slaapkamer')")
rule("global('Gordijn_Open_Slaapkamer_Procent')")

rule("global('Fake_Scene_Starten_Door_QA')")

rule("global('Media_TV')")

--beveiligen
rule("global('Z_Armed_01')")
rule("global('Z_Armed_02')")
rule("global('Z_Armed_03')")
rule("global('Z_Armed_04')")
rule("global('Z_Armed_05')")
rule("global('Z_Armed_06')")
rule("global('Z_Armed_07')")
rule("global('Z_Armed_08')")
rule("global('Z_Armed_09')")
rule("global('Z_Armed_10')")
rule("global('Z_Armed_11')")
rule("global('Z_Armed_12')")
rule("global('Z_Armed_13')")
rule("global('Z_Armed_14')")
rule("global('Z_Armed_15')")
rule("global('Z_Armed_16')")
rule("global('Z_Armed_17')")
rule("global('Z_Armed_18')")
rule("global('Z_Armed_19')")
rule("global('Z_Armed_20')")
rule("global('Z_Armed_21')")
rule("global('Z_Armed_22')")
rule("global('Z_Armed_23')")
rule("global('Z_Armed_24')")
rule("global('Z_Armed_25')")

--------------------------------------------------------
rule("log.skyblue('98-VERLICHTING TOESTAAN VOOR ALLE QA`s')")
---------------------------------------------------

--hier kun je verschil aanbrengen in starttijd verlichting per kamer aan of uit. Waarschijnlijk eerst de @ sunrise/ sunset vervroegen of verlaten alvorens dit te gebruiken
--moet dan wel een post zijn! kan nu even niet met post aan/afwezig

--$Hand_Instelling_Gordijn_Zithoek == 'Is_Gesloten'is gesloten
--#licht_Toestaan | 

--$Bezetting_Keuken == 'Bezet' | $Bezetting_Keuken == 'Vrij') & 


--$Verlichting_Appartement is permissie om licht aan te doen

--Licht toestaan of verboden puur sunrise-sunset
--om licht handmatig te kunnen aandoen indien het donker? is voor het automatisch aangaat

 --[[rule([[$Gordijn_Status_Zithoek | true =>
        log.pink('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  $>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Gordijn_Status_Zithoek >>> %s',$Gordijn_Status_Zithoek);
wait(0)
]]


------------
end


function QuickApp:test() print(6) end

function QuickApp:onInit()
  local str = "EventRunner 7, v"..fibaro.EventRunnerVersion
  self:debug(string.format("<font color='green'>%s</font>",str))
  self:updateView('info','text',str)
  fibaro.EventRunner(main)
end

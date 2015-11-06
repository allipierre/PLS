create or replace PACKAGE BODY PKG_WERK2 AS
   i_lfd_nr number default 0;
   i_bohren_ap varchar2(3) default null;
   find boolean default false;
   v_aplsatz_obj  host.arbeitsplan_record := HOST.arbeitsplan_record(null);
   
   p_isRevision boolean default  true;
   p_isCNCbearbeitet boolean default  false;  --läuft über CNC
   p_isTrocken boolean default true; -- Stein oder Scheibe ist trocken
   p_isRevision_abblasen boolean default true;
   p_isAbsatz_angebracht boolean default false;
   p_isForm_Profil boolean default false;
   p_iskugellagerlaufbahnscheiben boolean default false;
   p_isFeinschleifenAblauf boolean default false;
   --out
   
  PROCEDURE BON_0(
      prod_r produktions_record,
      find OUT BOOLEAN);;
      
  PROCEDURE vorplanieren(
      prod_r produktions_record); 
   PROCEDURE austreichen_bohrung(
      prod_r produktions_record);
    PROCEDURE bohrung_nacharbeiten(
      prod_r produktions_record);
   PROCEDURE ausspritzen_bohrung(
      prod_r produktions_record);
   --PROCEDURE reduring_bohrung(
    --  prod_r produktions_record);
   PROCEDURE trocknen(
    prod_r produktions_record);
   PROCEDURE schwefel(
      prod_r produktions_record);
      
  PROCEDURE traenken(
    prod_r produktions_record);
  
  PROCEDURE bandagieren(
    prod_r produktions_record);

PROCEDURE KA526_8(
    prod_r produktions_record);
    
PROCEDURE aufkitten_sonderablauf(
    prod_r produktions_record,    
  find OUT BOOLEAN);
  
    PROCEDURE honringe_sonderablauf(
      prod_r produktions_record,
      find OUT BOOLEAN);
  
  PROCEDURE tschudin_sonderablauf(
    prod_r produktions_record,    
  find OUT BOOLEAN);
  
  
  PROCEDURE start_werk2(
      prod_r produktions_record,
      p_lft_nr IN OUT NUMBER) AS
      
      p_array PKG_UTIL_APL.array_var_text_time;
  BEGIN
    find                  := false;
    i_bohren_ap           := null;
    p_isRevision          := true;
    p_isCNCbearbeitet     := false;
    p_isRevision_abblasen := true;
    p_isAbsatz_angebracht := false;
    p_isForm_Profil       := false;
    p_isTrocken           := true;
    p_isFeinschleifenAblauf := false;
    p_iskugellagerlaufbahnscheiben := false;
    p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
    DBMS_OUTPUT.PUT_LINE( 'start_werk2 -->   '|| prod_r.T_BEZEICHNUNG);
  
    -- Index für Arbeitsplan Nr laufenden nr.
    i_lfd_nr  := p_lft_nr;
    
    v_aplsatz_obj.T_MENGE        := prod_r.T_STUECK_WERK1; 
    --Werte für Arbeitsplan setzen
    v_aplsatz_obj.T_KOMMISSION   := prod_r.T_KOMMISSION;
    v_aplsatz_obj.T_POSITION     := prod_r.T_POSITION;
    v_aplsatz_obj.T_STRICHNUMMER := prod_r.T_STRICHNUMMER;
    v_aplsatz_obj.T_REZEPTNUMMER := prod_r.T_REZEPTNUMMER;
    v_aplsatz_obj.T_LFD_NR       := p_lft_nr;
    v_aplsatz_obj.T_DARSTELLUNG_KZ := 1;  --für Hauptsatz
    

      --Lagereingang?
    if   prod_r.T_KUNDENNUMMER = '05999' then
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'220',1,p_array,'951','start_Werk2_ Lagereingang');
        return;  --ende Arbeitsplan
    end if;

    --Lagerausgang?
    if   prod_r.T_LAGERKZ is not  null and  prod_r.T_LAGERKZ  in  ('B','G','L','U') then
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'240',1,p_array,'951','start_Werk2_ Lagerausgang');
    end if;
    
    /* Abgrenzungen der einzelnen Sonderabläufe */
     --Ablauf RLS
    if not find and prod_r.T_BEZEICHNUNG  = 'RLS' then
       RLS(prod_r,find);
    end if;
    
    --Sonderablauf für BON=0
    if  not find and prod_r.T_BEZEICHNUNG ='SLS' and prod_r.T_NENNBOHRUNG=0 then 
        BON_0(prod_r,find);
    end if;
    
    -- sonderablauf Honringe normal und Hybrid
    if not find and prod_r.T_KA5213 in ('1','2','3') then
       honringe_sonderablauf(prod_r,find);
    end if;
    
    
    --Taumelnaht Ablauf
    if not find and prod_r.T_KA5210 in ('2','3') then
        --DBMS_OUTPUT.PUT_LINE( 'WERK 2 Taumelnaht' );
       taumelnaht(prod_r,find);
    end if;

    --Mutternscheiben
    if not find then
        mutterscheiben(prod_r,find);
    end if;
    
        --Modulscheiben
    if not find  and prod_r.T_MODUL_NR >0 and prod_r.T_MODUL_EINGRIFFSWINKEL>0 then
        modulscheiben(prod_r,find);
    end if;
    
   
    --Ablauf CHAR=B
    if not find and prod_r.T_CHARAKTERISTIKA  = 'B' then
       CHARAKTERISTIKA_B(prod_r,find);
    end if;
    
       -- Kugellaufbahnscheiben
    if not find and  prod_r.T_BEZEICHNUNG='SLS' and  prod_r.T_CHARAKTERISTIKA  = 'V' then
      --DBMS_OUTPUT.PUT_LINE( 'WERK 2 Kugellaufbahnscheiben' );
       kugellagerlaufbahnscheiben(prod_r,find);
    end if;
    
        --aufkitten_sonderablauf     
    if not find and  prod_r.T_KA5211='T' then
       tschudin_sonderablauf(prod_r,find);
    end if;
    
    
    --aufkitten_sonderablauf     
    if not find and  prod_r.T_KA5211='F' then
       aufkitten_sonderablauf(prod_r,find);
    end if;
    
    
    --Standardablauf CNC
    if not find  then
       CNC(prod_r,find);
       
       if not p_isCNCbearbeitet then
         --Kunstharzinnenzone
            if prod_r.T_KA526 = '8' then
                --Info schreiben abgrenzung
                PKG_UTIL_APL.insert_abgrenzung(prod_r,'Kunstharzinnenzone ohne CNC');
                if (prod_r.T_PRESSBREITE-prod_r.T_NENNBREITE) > 2 then
                    vorplanieren(prod_r);
                    bohren(prod_r); --bohren
                    stirnen(prod_r);  --stirnen
                    KA526_8(prod_r); --kunstharzinnenzone
                    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,null,'624','start_Werk2_ ka526=8');--schleifen
                    PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,'start_Werk2_ ka526=8');
                      --trocknen
                    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',1,p_array,'677','start_Werk2_ ka526=8');
                    p_array(1) := '36';
                    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',2,p_array,'677','start_Werk2_ ka526=8');
                    form_profil(prod_r);
                    trocknen(prod_r);
                    traenken(prod_r);
                    schwefel(prod_r);
                else
                    planieren(prod_r); --planieren
                    bohren(prod_r); --bohren
                    KA526_8(prod_r); --kunstharzinnenzone
                    stirnen(prod_r);  --stirnen
                    form_profil(prod_r);
                    trocknen(prod_r);
                    traenken(prod_r);
                    schwefel(prod_r);
                end if;
            else --schleife Kunsthartinnenzone ende
            --normaler ablauf
                if prod_r.T_AUSSPARUNG1DN1>0 and  prod_r.T_AUSSPARUNG2DN1>0 then
                    --Info schreiben abgrenzung
                    PKG_UTIL_APL.insert_abgrenzung(prod_r,'STANDARD 2 AUSSPARUNGEN');
                    planieren(prod_r); --planieren
                    stirnen(prod_r);  --stirnen
                    bohren(prod_r); --bohren
                    traenken(prod_r);
                else
                    --normaler ablauf
                    --Info schreiben abgrenzung
                    PKG_UTIL_APL.insert_abgrenzung(prod_r,'STANDARDABLAUF');
                    planieren(prod_r); --planieren
                    bohren(prod_r); --bohren
                    if  PKG_UTIL_APL.is_ausspritzen_bohrung(prod_r)  then -- kanten härten/traenken mit Ausspritzen zusammen
                        traenken(prod_r);
                        ausspritzen_bohrung(prod_r);
                    end if;
                    --reduring_bohrung(prod_r);
                    stirnen(prod_r);  --stirnen
                    if  PKG_UTIL_APL.is_ausspritzen_bohrung(prod_r)  = false then -- nur kanten härten/traenken, wenn kein ausspritzen gesetzt ist
                        traenken(prod_r);
                    end if;
                    If p_isFeinschleifenAblauf then
                       planieren(prod_r); --planieren
                    end if;
                    
                end if; --Ende normaler Ablauf ohne Aussaprungen 1 und 2
            end if;--schleife normaler ablauf ende
       else
          traenken(prod_r);
          ausspritzen_bohrung(prod_r);
          KA526_8(prod_r); --kunstharzinnenzone
       end if;
       
    end if;
 
    if prod_r.T_KA526 <> '8' and not p_iskugellagerlaufbahnscheiben then
        form_profil(prod_r);
        trocknen(prod_r);
        schwefel(prod_r);
    end if;
    
    --QS jetzt für RLS
    if  prod_r.T_BEZEICHNUNG  = 'RLS' then
      --QS Prüfung Modul aufrufen
      i_lfd_nr :=  v_aplsatz_obj.T_LFD_NR;
      PKG_QUALITAETSPRUEFUNG.start_QUAL(prod_r,i_lfd_nr);
      v_aplsatz_obj.T_LFD_NR := i_lfd_nr ;
    end if;
    
    -- Ablauf Bandagieren
    bandagieren(prod_r);
    
    --Revision
    if prod_r.T_KA5211 = 'G' and prod_r.T_BEZEICHNUNG='SLS' then --ausnahmen
        --Hinweis Scheibe zuführen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',13,p_array,'592','start_Werk2_ ka5211=G');
    elsif p_isRevision then --Kz Revison, dann Arbeitsgaenge andrucken
        revision(prod_r,find);
    end if;
 
    p_lft_nr := i_lfd_nr;
    
EXCEPTION 
WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
  sqlerror :='ERROR -->PKG_WERK2.start_werk2 APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
  INSERT INTO LOGTAB
    (TEXT
    ) VALUES
    (sqlerror
    );
  END start_werk2;




/*
* Ablauf RLS
*
*
*/
  PROCEDURE RLS(
      prod_r produktions_record,
      find OUT BOOLEAN) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'RLS ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3); 
   i_arbeitsgang varchar2(3); 
   p_array PKG_UTIL_APL.array_var_text_time;
   i_is_fase boolean default true;
   i_text_id_fase number default 0;
      
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  
 
   
-- Abgrenzung RLS
    IF  prod_r.T_BEZEICHNUNG='RLS' then
        --Info schreiben abgrenzung
         PKG_UTIL_APL.insert_abgrenzung(prod_r,i_programm_name);
        
        if prod_r.T_K1KA582= '91' and prod_r.T_K1Feld1KA58=1 then
            i_text_id_fase := 103; -- 1= bohren ohne Fase
        elsif prod_r.T_K1KA582= '91' and prod_r.T_K1Feld1KA58=0 then
            i_text_id_fase := 104; -- 1= bohren + Fase anbringen
        end if;
        
        i_gruppen_id := 100;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',1,p_array,'182',i_programm);--Formen zusammenstellen
      
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'110',1,p_array,'182',i_programm);--giessen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'110',6,p_array,'182',i_programm);--auf mass
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',1,p_array,'182',i_programm);--evakuieren 
        
        if prod_r.T_PRESSBREITE <=160 then
            i_gruppen_id := 110;
            p_array(1) := '30';  
        else
            i_gruppen_id := 120;
            p_array(1) := '40'; 
        end if;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',1,p_array,'182',i_programm);--evakuieren dauer
           
        i_gruppen_id := 150;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'197',1,p_array,'182',i_programm);--aushaerten
        p_array(1) := '3'; 
        p_array(2) := '80'; 
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'197',3,p_array,'182',i_programm);--aushaerten
      
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',1,p_array,'182',i_programm);--ausformen
      
      --Werk 2
      if (prod_r.T_DN_MAX_TOL - prod_r.T_DN_MIN_TOL)<=0.2 or  -- besondere enge Tolernazen zb Kunde Tschudin GM
         (prod_r.T_BN_MAX_TOL - prod_r.T_BN_MIN_TOL)<=0.2 or 
         (prod_r.T_BON_MAX_TOL - prod_r.T_BON_MIN_TOL)<=0.2 or 
         (prod_r.T_STEG_MAX_TOL - prod_r.T_STEG_MIN_TOL)<=0.2 
         then
          i_gruppen_id := 200;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',1,p_array,'626',i_programm);--CNC Komplettbearbeitung
          PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm,6); 
          PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm,6);
          PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm,6);
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
      elsif prod_r.T_NENNBREITE > 150 then
          i_gruppen_id := 300;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'300',1,p_array,'544',i_programm);--Planieren bohren
          PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm); 
          PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',i_text_id_fase,p_array,'544',i_programm);
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,'540',i_programm);--Stirnen
          PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm); 
          if PKG_UTIL_APL.isAussparung(prod_r) then
              i_gruppen_id := 310;
              i_programm := i_programm_name || i_gruppen_id;
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'365',1,p_array,'544',i_programm);--aussparen
              PKG_UTIL_APL.setToleranz('AUSSPAR',v_aplsatz_obj,prod_r,i_programm,6);
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
          end if;
      elsif prod_r.T_NENNBREITE < 50 then  
          i_gruppen_id := 500;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,'624',i_programm);--planieren
          PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm); 
          if prod_r.T_NENNDURCHMESSER <= 300 and  prod_r.T_NENNBREITE <= 100 then
              if PKG_UTIL_APL.isAussparung(prod_r) then
                  i_gruppen_id := 500;
                  i_arbeitsplatz := '626';
                  i_arbeitsgang  := 'xxx';
              else
                  i_gruppen_id := 510;
                  i_arbeitsplatz := '626';
                  i_arbeitsgang  := '312';
              end if;
          else 
              if PKG_UTIL_APL.isAussparung(prod_r) then
                  i_gruppen_id := 520;
                  i_arbeitsplatz := '544';
                  i_arbeitsgang  := 'xxx';
              else
                  i_gruppen_id := 530;
                  i_arbeitsplatz := '544';
                  i_arbeitsgang  := '312';
              end if;
          end if;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,i_arbeitsgang,1,p_array,i_arbeitsplatz,i_programm);--
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',i_text_id_fase,p_array,i_arbeitsplatz,i_programm);
          
      else
          i_gruppen_id := 600;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'301',1,p_array,'544',i_programm);--planieren/stirnen
          PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm,6); 
          PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm,6); 
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
    
          if PKG_UTIL_APL.isAussparung(prod_r) then
              i_gruppen_id := 610;
              i_programm := i_programm_name || i_gruppen_id;
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'303',1,p_array,'544',i_programm);--planieren ausparen bohren
              PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm); 
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',i_text_id_fase,p_array,'544',i_programm);
          else
              i_gruppen_id := 620;
              i_programm := i_programm_name || i_gruppen_id;
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'300',1,p_array,'544',i_programm);--planieren  bohren
              PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm); 
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',i_text_id_fase,p_array,'544',i_programm);
         end if;
          
      end if;
        
    
      
              
        find := true;
    else
        find := false;
        return;
    END IF; 
   
    EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.RLS APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END RLS;

/*
* Ablauf Kugellaufbahnscheiben
*
*
*/
  PROCEDURE kugellagerlaufbahnscheiben(
      prod_r produktions_record,
      find OUT BOOLEAN) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'Kugellagerlaufbahn ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3); 
   p_array PKG_UTIL_APL.array_var_text_time;
      
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  p_iskugellagerlaufbahnscheiben := false;
  
-- Abgrenzung Kugellaufbahnscheiben
    IF ( prod_r.T_ANWENDUNGSSCHLUESSEL='34' or 
            (prod_r.T_KA524='9' and prod_r.T_K1KA582 in ('67','68')) or 
            (prod_r.T_K1KA582 in ('67','68')  and prod_r.T_KORNGROESSE > 70 and (prod_r.T_METER_JE_SEC >=63  or prod_r.T_nennBOHRUNG between 203 and 305))) and
        prod_r.T_BEZEICHNUNG='SLS' AND
        prod_r.T_PRESSDURCHMESSER1 >=400 AND prod_r.T_PRESSDURCHMESSER1 < 665 AND 
        prod_r.T_PRESSBOHRUNG>0 and
       (prod_r.T_PRESSBREITE-prod_r.T_Nennbreite) >= 3 AND 
        prod_r.T_Nennbreite>=3 AND prod_r.T_Nennbreite<=100 AND 
        (prod_r.T_CHARAKTERISTIKA='V' or 
        prod_r.T_K1KA582 IN ('67','68') or
        (prod_r.T_BN_MAX_TOL-prod_r.T_BN_MIN_TOL)<=0.2 )  THEN
        
        
        p_iskugellagerlaufbahnscheiben := true;
        
         --Info schreiben abgrenzung
         PKG_UTIL_APL.insert_abgrenzung(prod_r,i_programm_name);
         
         vorplanieren(prod_r);
        
        
        --bohren
        if prod_r.T_PRESSDURCHMESSER1 <=410 then
            i_gruppen_id := 8;
            i_arbeitsplatz := '503';
        else
            i_gruppen_id := 9;
            i_arbeitsplatz := '502';
        end if;
        
        --einfuegen bohren
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'330',1,p_array,i_arbeitsplatz,i_programm);
        --gleichzeitig bohren
        if i_arbeitsplatz = '502' then
           p_array(1) := trunc(150/prod_r.T_PRESSBREITE);
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'330',2,p_array,i_arbeitsplatz,i_programm);
        end if;
        PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm); 
        
        --stirnen
        if prod_r.T_KA5212='3' then
            null; --nicht stirnen
        else
          i_gruppen_id := 7;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,'540',i_programm);
          PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);            
        end if;
        
      
        
        --Kunsthartinnenzone
        if prod_r.T_KA526 = '8' then
            KA526_8(prod_r);
        else
            --abblasen
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);
        end if;
        
        
        --Schleifen kehren
        i_gruppen_id := 11;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'624',i_programm);
        PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm); 
        
        
        if prod_r.T_K1KA582 in ('67','68') or prod_r.T_K2KA582 in ('67','68') then
            --Absatz anbringen
             i_gruppen_id := 12;
             i_programm := i_programm_name || i_gruppen_id;
             PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'369',1,p_array,'624',i_programm);
             p_isAbsatz_angebracht := true;
        end if;
        if p_isAbsatz_angebracht then
          DBMS_OUTPUT.PUT_LINE('-->  p_isAbsatz_angebracht ' );
      end if;
        
         --trocknen
         i_gruppen_id := 13;
         i_programm := i_programm_name || i_gruppen_id;
         PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',1,p_array,'677',i_programm);
         p_array(1) := '36';
         PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',2,p_array,'677',i_programm);
        
        form_profil(prod_r);
        
         find := true;
    else--Abgrenzung nicht Kugellaufbahnscheiben, return false!
       -- DBMS_OUTPUT.PUT_LINE('--> keine Kugellaufbahnscheiben' );
        find := false;
        return;
    END IF; 
   
    EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.kugellagerlaufbahnscheiben APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END kugellagerlaufbahnscheiben;
  
  

/*
* Ablauf taumelnaht
*
*
*/
  PROCEDURE taumelnaht(
      prod_r produktions_record,
      find OUT BOOLEAN) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'Taumelnaht. ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3); 
   i_arbeitsplatz_cnc varchar2(3);
   p_array PKG_UTIL_APL.array_var_text_time;
   i_revision PKG_UTIL_APL.array_var_revision;
 
      
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  i_arbeitsplatz_cnc := PKG_UTIL_APL.getCNC_AP(prod_r,true);
  i_revision := PKG_UTIL_APL.getRevision_AP(prod_r);
  
-- Abgrenzung Taumelnaht ohne kitten
    IF  prod_r.T_KA5210='2'  THEN
         --Info schreiben abgrenzung
         PKG_UTIL_APL.insert_abgrenzung(prod_r,i_programm_name);
        
        --Vorplanieren BN+1mm
        i_gruppen_id := 10;
        i_arbeitsplatz := '547';
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',1,p_array,i_arbeitsplatz,i_programm);
            

        --Hinweis 1mm Aufmass
        i_gruppen_id := 7;
        i_programm := i_programm_name || i_gruppen_id;
        p_array(1) := '1';
        p_array(2) := to_char(prod_r.T_NENNBREITE + 1,'99G990D90');
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',2,p_array,i_arbeitsplatz,i_programm);
        
        
        --bohren
        if PKG_UTIL_APL.isAussparung(prod_r) then
            i_gruppen_id := 30;
              --einfuegen aussparen und bohren
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'316',1,p_array,i_arbeitsplatz_cnc,i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
            --PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);
            --PKG_UTIL_APL.setToleranz('AUSSPAR',v_aplsatz_obj,prod_r,i_programm);
        else
            i_gruppen_id := 40;
             --einfuegen bohren
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'330',1,p_array,i_arbeitsplatz_cnc,i_programm);
            PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm); 
        end if;
        
        
        --stirnen
        i_gruppen_id := 50;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,i_arbeitsplatz_cnc,i_programm);
        PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);     
                 
        --abblasen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);
        
        --auswuchten
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',1,p_array,i_revision(2),i_programm);--auswuchten
        --Vorgabe Kundenunwucht
        if prod_r.T_UMWUCHT_SOLL is null or prod_r.T_UMWUCHT_SOLL = '   ' then
            p_array(1) := PKG_UTIL_APL.getAuswuchtGewicht(prod_r);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',3,p_array,i_revision(2),i_programm); --umwucht gewicht
        else
            p_array(1) :=  prod_r.T_UMWUCHT_SOLL;  --Kundenwunsch Vorgabe
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',4,p_array,i_revision(2),i_programm); --umwucht gewicht
        end if;
        --Hinweis Schwerpunkt markieren
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',2,p_array,i_revision(2),i_programm);
        
        --*Tourenprüfung******************************************
        if  prod_r.T_METER_JE_SEC >=40 then
            i_gruppen_id := 80;
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'540',1,p_array,i_revision(3),i_programm); --tourenprüfung    
            p_array(1) := PKG_UTIL_APL.getPruefGeschwindigkeit(prod_r);
            if p_array(1)> to_number(i_revision(4)) then
                p_array(2) := i_revision(4);
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',10001,p_array,i_revision(3),i_programm); --Probe Geschwindigkeit! 
            end if;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'540',2,p_array,i_revision(3),i_programm); --Probe Geschwindigkeit! 
            if i_revision(3) = '709' then --zusatzinfo bei AP=709
                p_array(1) := PKG_UTIL_APL.getDrehzahleinstellung(PKG_UTIL_APL.getPruefGeschwindigkeit(prod_r));
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'540',3,p_array,i_revision(3),i_programm); --Drehzahleinstellung! 
                p_array(1) :=  round(p_array(1) * 1.5,1);
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'540',4,p_array,i_revision(3),i_programm); --Drehzahleinstellung! 
            end if;
      
        else
            i_gruppen_id := 81;
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'544',1,p_array,i_revision(1),i_programm); --Klankprüfung
        end if;
        -- end Tourenprüfung*******************************************
        
        
        --taumeldnaht anbringen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'323',1,p_array,i_arbeitsplatz_cnc,i_programm);
        
        --abblasen
       -- PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);
      
        find := true;
        
    --*************************************************************************    
    --***
    elsif prod_r.T_KA5210='3'  THEN -- Taumelnaht mit kitten
        --Vorplanieren BN+1mm
        i_gruppen_id := 120;
        i_arbeitsplatz := '547';
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',1,p_array,i_arbeitsplatz,i_programm);
    
        --Hinweis 1mm Aufmass
        p_array(1) := '1';
        p_array(2) := to_char(prod_r.T_NENNBREITE + 1,'99G990D90');
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',2,p_array,i_arbeitsplatz,i_programm);
        
        --Vor-bohren/aussparen
        if  PKG_UTIL_APL.isAussparung(prod_r) = false  then
            i_gruppen_id := 140;
            i_arbeitsplatz := '502';
            --einfuegen vorbohren
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'320',1,p_array,i_arbeitsplatz,i_programm);
        else
            i_gruppen_id := 150;
            --einfuegen aussparung vorschneiden
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'360',1,p_array,i_arbeitsplatz_cnc,i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'320',1,p_array,i_arbeitsplatz_cnc,i_programm);
            
        end if;
        
        --Vorstirnen +2mm
        i_gruppen_id := 160;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'350',1,p_array,i_arbeitsplatz_cnc,i_programm);
       
       --Hinweis 2mm Aufmass
        p_array(1) := '2';
        p_array(2) := to_char(prod_r.T_NENNDURCHMESSER + 2,'99G990D90');
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'350',2,p_array,i_arbeitsplatz_cnc,i_programm);
      
 
 
 
        --abblasen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);
    
        --auswuchten
        --i_arbeitsplatz := '   ';
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',1,p_array,i_revision(2),i_programm);
 
        --Hinweis Schwerpunkt markieren
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',2,p_array,i_revision(2),i_programm);
        
        --taumeldnaht anbringen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'323',1,p_array,i_arbeitsplatz_cnc,i_programm);
        
        --abblasen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);
 
        --kitten
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'285',1,p_array,'592',i_programm);
 
         --planieren/aussparen
        if  PKG_UTIL_APL.isAussparung(prod_r) = false  then
            i_gruppen_id := 230;
            --i_arbeitsplatz := '503';
            --einfuegen vorbohren
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'359',1,p_array,i_arbeitsplatz_cnc,i_programm);
            PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm,6); 
            PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm,6); 
            PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm,6); 
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz_cnc,i_programm);-- Abmessung
        else
            i_gruppen_id := 240;
            --i_arbeitsplatz := '360';
            --einfuegen aussparung schneiden/ fertig aussparen
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'XXX',1,p_array,i_arbeitsplatz_cnc,i_programm);
            PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm,6); 
            PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm,6); 
            PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm,6); 
            PKG_UTIL_APL.setToleranz('AUSSPAR',v_aplsatz_obj,prod_r,i_programm,6);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz_cnc,i_programm);-- Abmessung
        end if;
        
       
         --abblasen ist im Ablauf revision enthalten
       -- i_gruppen_id := 250;
       -- i_programm := i_programm_name || i_gruppen_id;
       -- PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);
      
      
        find := true;

   else--Abgrenzung, return false!
        find := false;
        return;
    END IF; 
   
    EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.taumelnaht id:->>' ||i_gruppen_id||' APLNR:'||prod_r.T_arbeitsplannummer||' Error:'|| SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );

  END taumelnaht;
  
  
  /*
* Ablauf honringe_sonderablauf
*
*
*/
  PROCEDURE honringe_sonderablauf(
      prod_r produktions_record,
      find OUT BOOLEAN) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'honringe_sonderablauf. ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3); 
   i_arbeitsplatz_cnc varchar2(3);
   p_array PKG_UTIL_APL.array_var_text_time;
   i_revision PKG_UTIL_APL.array_var_revision;
 
      
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  i_arbeitsplatz_cnc := PKG_UTIL_APL.getCNC_AP(prod_r);
  i_revision := PKG_UTIL_APL.getRevision_AP(prod_r);
  
  --Info schreiben abgrenzung
  PKG_UTIL_APL.insert_abgrenzung(prod_r,i_programm_name);
  
  --Vorbohren BON - 2mm
  i_gruppen_id   := 10;
  i_arbeitsplatz := '544';
  i_programm := i_programm_name || i_gruppen_id;
  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'320',1,p_array,i_arbeitsplatz,i_programm);
  --Hinweis 2mm Aufmass
  i_gruppen_id := 7;
  i_programm := i_programm_name || i_gruppen_id;
  p_array(1) := '2';
  p_array(2) := to_char(prod_r.T_NENNBOHRUNG - 2,'99G990D90');
  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'320',2,p_array,i_arbeitsplatz,i_programm);
        
  --vorstirnen
  i_arbeitsplatz := '626';
  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'350',1,p_array,i_arbeitsplatz,i_programm);
  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'350',3,p_array,i_arbeitsplatz,i_programm);
  --Hinweis 2mm Aufmass
  p_array(1) := '2';
  p_array(2) := to_char(prod_r.T_NENNDURCHMESSER + 2,'99G990D90');
  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'350',2,p_array,i_arbeitsplatz,i_programm);
      
  --brennen
  --PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'200',2,p_array,'391',i_programm);
  i_lfd_nr :=  v_aplsatz_obj.T_LFD_NR;
  PKG_OFENHAUS.start_ofenhaus( prod_r,i_lfd_nr);
  v_aplsatz_obj.T_LFD_NR := i_lfd_nr ;
       
  --QS Prüfung Modul aufrufen
  i_lfd_nr :=  v_aplsatz_obj.T_LFD_NR;
  PKG_QUALITAETSPRUEFUNG.start_QUAL(prod_r,i_lfd_nr);
  v_aplsatz_obj.T_LFD_NR := i_lfd_nr ;
 
  --vorplanieren
  i_arbeitsplatz := '546';
  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',1,p_array,i_arbeitsplatz,i_programm);
  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',4,p_array,i_arbeitsplatz,i_programm);
  --Hinweis 2mm Aufmass
  p_array(1) := '2';
  p_array(2) := to_char(prod_r.T_NENNBREITE + 2,'99G990D90');
  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',2,p_array,i_arbeitsplatz,i_programm);
 
  --bohren
  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'330',1,p_array,'544',i_programm);
  PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);     
  
  -- Abgrenzung Honringe Hybrid
  IF  prod_r.T_KA5214='H'  THEN
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',11,p_array,'   ',i_programm); --Epoxi Abteilung
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',355,p_array,'   ',i_programm);
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',356,p_array,'   ',i_programm);
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',350,p_array,'   ',i_programm);
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',351,p_array,'   ',i_programm);
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',352,p_array,'   ',i_programm);
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',353,p_array,'   ',i_programm);
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',354,p_array,'   ',i_programm);
  end if;
  
  IF  prod_r.T_KA5213='1'  THEN
      --schleifen
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'624',i_programm);
      PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);     
  
      --Profil anbringen
      form_profil(prod_r);
      p_isForm_Profil := true;
      
      --Aussparung
      if  PKG_UTIL_APL.isAussparung(prod_r) = true then
          i_gruppen_id   := 100;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'365',1,p_array,'544',i_programm);
          PKG_UTIL_APL.setToleranz('AUSPAR',v_aplsatz_obj,prod_r,i_programm);     
      end if;
     
      --O-Ring  einbringen
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'373',1,p_array,'626',i_programm);
      
      --Mass und Sichtkontrolle
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'562',1,p_array,626,i_programm);--Sichtkontrolle
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'561',1,p_array,626,i_programm);--Masskontrolle
      p_array(1) :=   to_char(prod_r.T_PLAN_TOL,'0D0');
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'543',2,p_array,626,i_programm);--Stückzahl und Planparallelität
      
      find := true;
      
  -- Abgrenzung Honringe Ablauf 2 (wegen enge Toleranzen)
  elsIF  prod_r.T_KA5213='2'  THEN
   
      if prod_r.T_KA5214='H' then
          i_gruppen_id   := 100;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'624',i_programm);--schleifen
          PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);     
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,'626',i_programm);--stirnen
          PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm); 
      else
          i_gruppen_id   := 105;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,'626',i_programm);--stirnen
          PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);     
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'624',i_programm);--schleifen
          PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);     
      end if;
  
     
       --Aussparung
      if  PKG_UTIL_APL.isAussparung(prod_r) = true then
          i_gruppen_id   := 100;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'365',1,p_array,'544',i_programm);
          PKG_UTIL_APL.setToleranz('AUSSPAR',v_aplsatz_obj,prod_r,i_programm);     
      end if;
      
      --Mass und Sichtkontrolle
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'562',1,p_array,626,i_programm);--Sichtkontrolle
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'561',1,p_array,626,i_programm);--Masskontrolle
      p_array(1) :=   to_char(prod_r.T_PLAN_TOL,'0D0');
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'543',2,p_array,626,i_programm);--Stückzahl und Planparallelität
  else--Abgrenzung, return false!
        find := false;
        return;
    END IF; 
   
    EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.honringe_sonderablauf id:->>' ||i_gruppen_id||' APLNR:'||prod_r.T_arbeitsplannummer||' Error:'|| SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );

  END honringe_sonderablauf;


/*
* Ablauf aufkitten_sonderablauf
*
*
*/
  PROCEDURE aufkitten_sonderablauf(
      prod_r produktions_record,
      find OUT BOOLEAN) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'aufkitten_sonderablauf ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3); 
   i_arbeitsplatz_cnc varchar2(3);
   p_array PKG_UTIL_APL.array_var_text_time;
   i_revision PKG_UTIL_APL.array_var_revision;
 
      
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  i_arbeitsplatz_cnc := PKG_UTIL_APL.getCNC_AP(prod_r,true);
  i_revision := PKG_UTIL_APL.getRevision_AP(prod_r);
  
-- Abgrenzung Sonderablauf aufkitten 3 Satzscheiben
    IF  prod_r.T_KA5211='F'  THEN
         --Info schreiben abgrenzung
         PKG_UTIL_APL.insert_abgrenzung(prod_r,i_programm_name);
        
        --VorPlanieren BN+1mm
        i_gruppen_id := 10;
        i_arbeitsplatz := '545';
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',1,p_array,i_arbeitsplatz,i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',5,p_array,i_arbeitsplatz,i_programm);
        
        --Hinweis 2mm Aufmass
        p_array(1) := '2';
        p_array(2) := to_char(prod_r.T_NENNBREITE + 2,'99G990D90');
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',2,p_array,i_arbeitsplatz,i_programm);
        
        --stirnen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,i_arbeitsplatz_cnc,i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',5,p_array,i_arbeitsplatz_cnc,i_programm);
        PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);   
        
        --Form und Profil Bearbeitung Ansatz anbringen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'370',1,p_array,i_arbeitsplatz_cnc,i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'370',4,p_array,i_arbeitsplatz_cnc,i_programm);--Ansatz anbringen
        p_isForm_Profil := true;  --KZ Profil ist angebracht
        
        --Planieren 
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,i_arbeitsplatz_cnc,i_programm);
         --Hinweis 1mm Aufmass
        p_array(1) := '1';
        p_array(2) := to_char(prod_r.T_NENNBREITE + 1,'99G990D90');
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',6,p_array,i_arbeitsplatz,i_programm);
       
       
        --bohren
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'330',1,p_array,i_arbeitsplatz_cnc,i_programm);
        PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm); 
      
        --abblasen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);
        
        --auswuchten
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',1,p_array,i_revision(2),i_programm);--auswuchten
        --Hinweis Schwerpunkt markieren
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',2,p_array,i_revision(2),i_programm);
        
        
        --Hinweis Scheibe zuführen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',13,p_array,'592',i_programm);
        
        --aufkitten
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'285',1,p_array,'592',i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'285',3,p_array,'592',i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'285',4,p_array,'592',i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'285',5,p_array,'592',i_programm);
 
      
        --trocknen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',1,p_array,'592',i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',6,p_array,'592',i_programm);
        
        --schleifen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,i_arbeitsplatz_cnc,i_programm);
        PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);     
          
        find := true;

   else--Abgrenzung, return false!
        find := false;
        return;
    END IF; 
   
    EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.aufkitten_sonderablauf id:->>' ||i_gruppen_id||' APLNR:'||prod_r.T_arbeitsplannummer||' Error:'|| SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );

  END aufkitten_sonderablauf;
  
  
/*
* Ablauf tschudin_sonderablauf
*
*
*/
  PROCEDURE tschudin_sonderablauf(
      prod_r produktions_record,
      find OUT BOOLEAN) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'tschudin_sonderablauf. ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3); 
   i_arbeitsplatz_cnc varchar2(3);
   p_array PKG_UTIL_APL.array_var_text_time;
  
      
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  i_arbeitsplatz_cnc := PKG_UTIL_APL.getCNC_AP(prod_r,true);
 
  
-- Abgrenzung Sonderablauf Tschudin
    IF  prod_r.T_KA5211='T'  THEN
         --Info schreiben abgrenzung
         PKG_UTIL_APL.insert_abgrenzung(prod_r,i_programm_name);
        
        --VorPlanieren BN+1mm
        i_gruppen_id := 10;
        i_arbeitsplatz := '545';
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',1,p_array,i_arbeitsplatz,i_programm);
        
        --Hinweis 2mm Aufmass
        p_array(1) := '2';
        p_array(2) := to_char(prod_r.T_NENNBREITE + 2,'99G990D90');
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',2,p_array,i_arbeitsplatz,i_programm);
        
        --stirnen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,'540',i_programm);
        PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);   
        
        
        --Aussparung
        if  PKG_UTIL_APL.isAussparung(prod_r) = true then
            i_gruppen_id   := 100;
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,i_arbeitsplatz_cnc,i_programm);
             --Hinweis 1mm Aufmass
            p_array(1) := '1';
            p_array(2) := to_char(prod_r.T_NENNBREITE + 1,'99G990D90');
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',9,p_array,i_arbeitsplatz_cnc,i_programm);
            --aussparen
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'365',1,p_array,i_arbeitsplatz_cnc,i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        else
            i_gruppen_id   := 100;
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,i_arbeitsplatz_cnc,i_programm);
            --Hinweis 1mm Aufmass
            p_array(1) := '1';
            p_array(2) := to_char(prod_r.T_NENNBREITE + 1,'99G990D90');
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',10,p_array,i_arbeitsplatz_cnc,i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        end if;
       
       
        --bohren
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'330',1,p_array,i_arbeitsplatz_cnc,i_programm);
        PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm); 
      
       -- Hinweis zum vermessen der Scheibe
       PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',14,p_array,i_arbeitsplatz,i_programm);-- Abmessung/Meßprotokoll
        
        --abblasen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);
        
        --schleifen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'624',i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',8,p_array,'624',i_programm);
        PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);     
        
        --trocknen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'470',1,p_array,'677',i_programm);
        p_array(1) := '24';
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'470',2,p_array,'677',i_programm);  
        
        find := true;

   else--Abgrenzung, return false!
        find := false;
        return;
    END IF; 
   
    EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.tschudin_sonderablauf id:->>' ||i_gruppen_id||' APLNR:'||prod_r.T_arbeitsplannummer||' Error:'|| SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );

  END tschudin_sonderablauf;  
  

 /*
* Ablauf seitlich_kitt
*
*
*/
  PROCEDURE seitlich_kitt(
      prod_r produktions_record,
      find OUT BOOLEAN) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'seitlich_kitt ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3); 
   p_array PKG_UTIL_APL.array_var_text_time;
   
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  find := false; 
-- Abgrenzung seitlich mit Kitt
    IF  prod_r.T_KA526='4' THEN
         --Info schreiben abgrenzung
         PKG_UTIL_APL.insert_abgrenzung(prod_r,i_programm_name);
        
        --Planieren
        i_arbeitsplatz := PKG_UTIL_APL.getPlanierBank_AP(prod_r,i_gruppen_id);
        i_gruppen_id := i_gruppen_id||100;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,i_arbeitsplatz,i_programm);
        PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);     
        
        
        --1. Seite seitlich mit Kitt
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'295',1,p_array,'592',i_programm);
        
        --aushärten
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'296',1,p_array,'592',i_programm);
        p_array(1) := '24';
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'296',2,p_array,'592',i_programm);
        
        --Kittseite  planieren CNC
        i_arbeitsplatz := PKG_UTIL_APL.getCNC_AP(prod_r,true);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,i_arbeitsplatz,i_programm);
        PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);     
        
        --2. Seite seitlich mit Kitt
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'297',1,p_array,'592',i_programm);
        
        --aushärten 2. Seite
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'298',1,p_array,'592',i_programm);
        p_array(1) := '24';
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'298',2,p_array,'592',i_programm);
        
        -- planieren bohren CNC
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'300',1,p_array,i_arbeitsplatz,i_programm);
        PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);     
        PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);     
        find := true; 
        p_isCNCbearbeitet := true;
     end if;
    
   
    EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.seitlich_kitt Abgrenzung ->>ID:' ||prod_r.T_ID||' '|| SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.seitlich_kitt APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END seitlich_kitt;
 
/*
* Ablauf mutternscheiben
*
*
*/
  PROCEDURE mutterscheiben(
      prod_r produktions_record,
      find OUT BOOLEAN) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'Mutterscheiben ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3);
   i_arbeitsplatz_cnc varchar2(3);
   i_arbeitsplatz_plan varchar2(3);
   p_array PKG_UTIL_APL.array_var_text_time;
   
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
   
-- Abgrenzung Scheibe als Trageteller oder Boden
    IF  prod_r.T_KA521='5' THEN
         --Info schreiben abgrenzung
         PKG_UTIL_APL.insert_abgrenzung(prod_r,i_programm_name);
        
        if prod_r.T_NENNDURCHMESSER <= 500 then
            --Planieren
            i_gruppen_id := 10;
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,'546',i_programm);
            PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);     
             --Hinweis 2mm Aufmass
            p_array(1) := '2';
            p_array(2) := to_char(prod_r.T_NENNBREITE + 2,'9G990D90');
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',2,p_array,'546',i_programm);
            --schleifen planieren
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'501',i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',2,p_array,'501',i_programm);
            PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);  
            --abblasen
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);
            
        elsif prod_r.T_NENNDURCHMESSER <= 915 then
             --Planieren
            i_gruppen_id := 20;
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,'547',i_programm);
             --Hinweis 2mm Aufmass
            p_array(1) := '2';
            p_array(2) := to_char(prod_r.T_NENNBREITE + 2,'9G990D90');
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',2,p_array,'547',i_programm);
             --abblasen
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);
        else
            --Fehler Abgrenzung
            raise ABGRENZUNG_FEHLER;
        end if;
        p_isRevision := false; -- Boden nicht später Revision andrucken!
        
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',13,p_array,'591',i_programm);
        find := true;
        
     elsif  prod_r.T_KA522 in ('1','2') and  prod_r.T_KA528>0 then --Mutternscheiben (ohne zusätzlichen Boden)
         PKG_UTIL_APL.insert_abgrenzung(prod_r,i_programm_name);
        --Planieren Gewindeseite
        i_gruppen_id := 100;
        i_programm := i_programm_name || i_gruppen_id;
        i_arbeitsplatz_plan := PKG_UTIL_APL.getPlanierBank_AP(prod_r,i_gruppen_id);
        i_programm := i_programm || '-'|| i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,i_arbeitsplatz_plan,i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',8,p_array,i_arbeitsplatz_plan,i_programm);
             
            
        --Muttern ansenken
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'292',1,p_array,'537',i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'292',2,p_array,'537',i_programm);
        PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
        
      --  if prod_r.T_NENNDURCHMESSER <= 500 then
        --CNC Komplettbearbeitung
        i_gruppen_id := 110;
        i_programm := i_programm_name || i_gruppen_id;
        i_arbeitsplatz_cnc :=  PKG_UTIL_APL.getCNC_AP(prod_r,true); 
        if i_arbeitsplatz_cnc is null or i_arbeitsplatz_cnc='   ' then
             --Fehler Abgrenzung
             --raise ABGRENZUNG_FEHLER;
             INSERT INTO LOGTAB
              (TEXT) VALUES ('mutterscheiben: i_arbeitsplatz_cnc is null, kein CNC Arbeitsplatz: Abgrenzung!' );
        end if;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',1,p_array,i_arbeitsplatz_cnc,i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz_cnc,i_programm);-- Abmessung
            --PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);   
            --PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);   
      /*  elsif prod_r.T_NENNDURCHMESSER <= 914 then
            --CNC Komplettbearbeitung
            i_gruppen_id := 120;
            i_programm := i_programm_name || i_gruppen_id;
            i_arbeitsplatz_cnc :=  PKG_UTIL_APL.getCNC_AP(prod_r); 
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',1,p_array,i_arbeitsplatz_cnc,i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz_cnc,i_programm);-- Abmessung
            --PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);   
            --PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm); 
        else
            --Fehler Abgrenzung
            raise ABGRENZUNG_FEHLER;
        end if;*/
        find := true;
    elsif  prod_r.T_KA524='2' and  prod_r.T_KA528>0 then
        PKG_UTIL_APL.insert_abgrenzung(prod_r,i_programm_name);
        if prod_r.T_NENNDURCHMESSER <= 500 then
            --Planieren
            i_gruppen_id := 200;
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,'546',i_programm);
            PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);     
   
            --Hinweis 2mm Aufmass
            p_array(1) := '2';
            p_array(2) := to_char(prod_r.T_NENNBREITE + 2,'9G990D90');
            
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',2,p_array,'546',i_programm);
             --abblasen
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);
             --Hinweis Boden zuführen
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',6,p_array,'   ',i_programm);
             --aufkitten
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'285',1,p_array,'592',i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'285',2,p_array,'592',i_programm);
             --Hinweis 24h trocknen
            p_array(1) := '24';
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',7,p_array,'   ',i_programm);
            --planieren/bohren
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'300',1,p_array,'544',i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'300',2,p_array,'544',i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
            --PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);   
            --PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);   
            --Muttern ansenken
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'291',1,p_array,'544',i_programm);
            --stirnen
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,'540',i_programm);
            PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);   
            
        elsif prod_r.T_NENNDURCHMESSER <= 915 then
            --Planieren
            i_gruppen_id := 300;
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,'547',i_programm);
            --Hinweis 2mm Aufmass
            p_array(1) := '2';
            p_array(2) := to_char(prod_r.T_NENNBREITE + 2,'9G990D90');
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',3,p_array,'547',i_programm);
             --abblasen
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);
            --Hinweis Boden zuführen
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',6,p_array,'   ',i_programm);
              --aufkitten
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'285',1,p_array,'592',i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'285',2,p_array,'592',i_programm);
             --Hinweis 24h trocknen
            p_array(1) := '24';
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',7,p_array,'   ',i_programm);
            --schleifen Boden und Muttern ansenken
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'292',1,p_array,'537',i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'292',2,p_array,'537',i_programm);
            PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
       
             --bohren stirnen
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'312',1,p_array,'535',i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'312',2,p_array,'535',i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'312',3,p_array,'535',i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'312',4,p_array,'535',i_programm);
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'312',5,p_array,'535',i_programm);
        else
            --Fehler Abgrenzung
            raise ABGRENZUNG_FEHLER;
        end if;
         find := true;
    else--Abgrenzung nicht Mutternscheiben, return false!
        find := false;
        return;
    END IF; 
    
    
    --Kanten härten
    if prod_r.T_KA526='9' then
        i_gruppen_id := 350;
        i_programm := i_programm_name || i_gruppen_id;
        --abblasen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);
        --Kanten härten
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',1,p_array,'594',i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',2,p_array,'594',i_programm);
        --Ofen trocknen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',2,p_array,'595',i_programm);
    end if;
    
     --schlitzen
    if prod_r.T_KA5210='1' then
        i_gruppen_id := 360;   
        i_programm := i_programm_name || i_gruppen_id;
        --schlitzen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'380',1,p_array,'590',i_programm);
        if prod_r.T_ZEICHNUNGSNR is not null or trim(prod_r.T_ZEICHNUNGSNR) is not null then
                i_gruppen_id := 370;
                i_programm := i_programm_name || i_gruppen_id;
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'380',2,p_array,'645',i_programm);--laut Zeichnung
        end if;
    end if;
    
   
    EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.mutterscheiben Abgrenzung ->>APLNR:' ||prod_r.T_arbeitsplannummer||' i_gruppen_id:'||i_gruppen_id|| ' '|| SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.mutterscheiben APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END mutterscheiben;
  
  
  
  /*
* Ablauf mutternscheiben
*
*
*/
  PROCEDURE CHARAKTERISTIKA_B(
      prod_r produktions_record,
      find OUT BOOLEAN) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'CHARAKTERISTIKA_B ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3); 
   p_array PKG_UTIL_APL.array_var_text_time;
   i_AB6  boolean default false;
   i_AB7  boolean default false;
   i_S6  boolean default false;
   i_S7  boolean default false;
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  
  
   --Info schreiben abgrenzung
    PKG_UTIL_APL.insert_abgrenzung(prod_r,i_programm_name);
   
-- Abgrenzung Scheibe als Trageteller oder Boden
    IF  prod_r.T_BEZEICHNUNG='RLS' THEN
        if prod_r.T_K1KA582='91' then
            
            --Planieren stirnen
            i_gruppen_id := 10;
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'301',1,p_array,'544',i_programm);
            PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);     
            PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);     
          
            -- mit Aussparung
            if prod_r.T_AUSSPARUNG1DN1>0 or prod_r.T_AUSSPARUNG2DN1>0 then
                i_gruppen_id := 15;
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'303',1,p_array,'544',i_programm); --plan, auspar, bohren
                PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);   
            else -- ohne Aussparung 
                i_gruppen_id := 20;
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'300',1,p_array,'544',i_programm);--plan, bohren
                PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);   
            end if;
            
             --QS Prüfung Modul aufrufen
            i_lfd_nr :=  v_aplsatz_obj.T_LFD_NR;
            PKG_QUALITAETSPRUEFUNG.start_QUAL(prod_r,i_lfd_nr);
            v_aplsatz_obj.T_LFD_NR := i_lfd_nr ;
            
            find := true;
            
        else
            --Fehler Abgrenzung
            raise ABGRENZUNG_FEHLER;
        end if;
        
        
    elsif prod_r.T_K1KA582='91' then
        if  prod_r.T_KA5211 ='N' then
            find := true; -- keine APLAN
        elsif prod_r.T_KA524 ='2' and prod_r.T_NENNDURCHMESSER = '585' then
            --Planieren einseitig
            i_gruppen_id := 100;
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,'539',i_programm);--planieren einseitig
            p_array(1) := '55,50mm';
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',5,p_array,'539',i_programm);-- einseitig auf 55,5mm
            PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
            
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);--abblasen
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'285',1,p_array,'592',i_programm);--aufkitten
            
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'292',1,p_array,'592',i_programm);--schleifen/Muttern ansenken
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'330',1,p_array,'535',i_programm);--bohren
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,'540',i_programm);--stirnen
            find := true;
        else
            if  prod_r.T_PRESSDURCHMESSER1 <=820 and  prod_r.T_PRESSBREITE<=200 and   prod_r.T_EINSATZGEWICHT1_G<=40000 then
                i_gruppen_id := 110;
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'624',i_programm);--schleifen
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',3,p_array,'624',i_programm);--
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',4,p_array,'624',i_programm);--
            else
                i_gruppen_id := 120;
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'539',i_programm);--schleifen
            end if;
            
            i_gruppen_id := 150;  
            
            --KZ Ablauf bestimmen
            if  (prod_r.T_PRESSDURCHMESSER1<=364 and  prod_r.T_PRESSBREITE<=180 and prod_r.T_PRESSBOHRUNG between 50 and 299.9) or 
                (prod_r.T_PRESSDURCHMESSER1<=364 and  prod_r.T_PRESSBREITE<=120 and prod_r.T_PRESSBOHRUNG between 18 and 49.9) then
                i_AB6 := true;
            elsif (prod_r.T_PRESSDURCHMESSER1<=750 and  prod_r.T_PRESSBREITE>33 and prod_r.T_PRESSBOHRUNG >=125) then
                i_AB7 := true;
            else
                --Fehler Abgrenzung
                raise ABGRENZUNG_FEHLER;
            end if;
            
            --KZ Ablauf bestimmen
            if  (prod_r.T_PRESSDURCHMESSER1<=415 and  prod_r.T_PRESSBREITE<=200 and prod_r.T_PRESSBOHRUNG between 80 and 340.9) or 
                (prod_r.T_PRESSDURCHMESSER1<=300 and  prod_r.T_PRESSBREITE<=360 and prod_r.T_PRESSBOHRUNG >=20) then
                i_S6 := true;
            elsif (prod_r.T_PRESSDURCHMESSER1<=750) then
                i_S7 := true;
            else
                --Fehler Abgrenzung
                raise ABGRENZUNG_FEHLER;
            end if;
            
            --jetzt Ausgabe APLAN
            if i_S6 then
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,'660',i_programm);--stirnen                
            end if;
            
            if i_AB6 then
                if prod_r.T_K1FELD1KA58=1 then
                    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'330',1,p_array,'660',i_programm);--bohren                
                    PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);
                else
                    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'330',1,p_array,'660',i_programm);--bohren                
                    PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);
                end if;
                
                 -- mit Aussparung
                if prod_r.T_AUSSPARUNG1DN1>0 or prod_r.T_AUSSPARUNG2DN1>0 then
                    i_gruppen_id := 15;
                    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'365',1,p_array,'662',i_programm); --Aussparung
                end if;
                find := true;
            elsif i_AB7 then
                if prod_r.T_K1FELD1KA58=1 then
                    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'330',1,p_array,'539',i_programm);--bohren                
                    PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);
                else
                    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'330',1,p_array,'539',i_programm);--bohren Fase anbringen                
                    PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);
                end if;
                
                if i_S7 then
                    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,'539',i_programm);--stirnen   
                    PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);
                end if;
                
                 -- mit Aussparung
                if prod_r.T_AUSSPARUNG1DN1>0 or prod_r.T_AUSSPARUNG2DN1>0 then
                    i_gruppen_id := 15;
                    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'365',1,p_array,'539',i_programm); --Aussparung
                end if;
                find := true;
            end if;
            
            
        end if;
        
    else --Abgrenzung nicht prod_r.T_K1KA582='91', return false!
        find := false;
        return;
    END IF; 
   
    EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.CHARAKTERISTIKA_B Abgrenzung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.CHARAKTERISTIKA_B APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror  
        );
  END CHARAKTERISTIKA_B;
  
  
/*
* Ablauf modulscheiben
*
*
*/
  PROCEDURE modulscheiben(
      prod_r produktions_record,
      find OUT BOOLEAN) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'modulscheiben ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3); 
   p_array PKG_UTIL_APL.array_var_text_time;
   i_AB6  boolean default false;
   i_AB7  boolean default false;
   i_S6  boolean default false;
   i_S7  boolean default false;
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
   
    --QS Prüfung Modul aufrufen
   -- i_lfd_nr :=  v_aplsatz_obj.T_LFD_NR;
  --  PKG_QUALITAETSPRUEFUNG.start_QUAL(prod_r,i_lfd_nr);
  --  v_aplsatz_obj.T_LFD_NR := i_lfd_nr ;
     
    --Info schreiben abgrenzung
    PKG_UTIL_APL.insert_abgrenzung(prod_r,i_programm_name);
            
    --Vorplanieren einseitig
    i_gruppen_id := 10;
    i_programm := i_programm_name || i_gruppen_id;
    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',1,p_array,'546',i_programm);--planieren
    p_array(1) := '1';
    p_array(2) := to_char(prod_r.T_NENNBREITE + 1,'9G990D90');
    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',6,p_array,'546',i_programm);-- +1mm
   

    --Innenzone getraenkt
    if prod_r.T_KA526 = '8' then
        KA526_8(prod_r);
    end if;
            
    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'300',1,p_array,'544',i_programm);--bohren planieren
    PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
    PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);
    
    If prod_r.T_MODUL_NR >= 2.25 or  (prod_r.T_MODUL_NR <=2.25 and prod_r.T_MODULGANG in ('3','5')) then
        i_gruppen_id := 20;  
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,'544',i_programm);--stirnen auf DN
        PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'375',1,p_array,'544',i_programm);-- Modulbearbeitung anbringen
        p_array(1) := to_char(prod_r.T_MODUL_NR,'999D99');
        p_array(2) := to_char(prod_r.T_MODUL_EINGRIFFSWINKEL,'990D9');
        p_array(3) := to_char(prod_r.T_MODULGANG,'99');
        p_array(4) := prod_r.T_MODULDREHRICHTUNG;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'375',2,p_array,'661',i_programm);-- Modulbearbeitung Info
        find := true;
    elsif  prod_r.T_MODUL_EINGRIFFSWINKEL in (15,16,17,17.5,20,22,24,25,27,35) and prod_r.T_MODULGANG in ('1','2') then
        i_gruppen_id := 20;   
        i_gruppen_id := 30;  
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,'661',i_programm);--stirnen auf DN
        PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',2,p_array,'661',i_programm);--stirnen 
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'375',1,p_array,'661',i_programm);-- Modulbearbeitung anbringen
        p_array(1) := to_char(prod_r.T_MODUL_NR,'999D99');
        p_array(2) := to_char(prod_r.T_MODUL_EINGRIFFSWINKEL,'990D9');
        p_array(3) := to_char(prod_r.T_MODULGANG,'99');
        p_array(4) := prod_r.T_MODULDREHRICHTUNG;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'375',2,p_array,'661',i_programm);-- Modulbearbeitung Info
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'375',3,p_array,'661',i_programm);-- Modulbearbeitung 
        find := true;
    else
        --Fehler Abgrenzung
        raise ABGRENZUNG_FEHLER;
    end if;   

   
    EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.modulscheiben Winkel:'||prod_r.T_MODUL_EINGRIFFSWINKEL|| ' ' || ' Abgrenzung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB(TEXT) VALUES(sqlerror);
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.modulscheiben APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror  
        );
  END modulscheiben;
  
  
  
/*
* Ablauf BON_0
*
*
*/
  PROCEDURE BON_0(
      prod_r produktions_record,
      find OUT BOOLEAN) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'BON_0 ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3); 
   p_array PKG_UTIL_APL.array_var_text_time;
   i_AB6  boolean default false;
   i_AB7  boolean default false;
   i_S6  boolean default false;
   i_S7  boolean default false;
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
   
   if prod_r.T_BEZEICHNUNG ='SLS' and prod_r.T_NENNBOHRUNG=0 and 
      prod_r.T_NENNDURCHMESSER > 10 and prod_r.T_NENNDURCHMESSER < 20 and 
      prod_r.T_PRESSBREITE >= (prod_r.T_NENNBREITE + 7)  and prod_r.T_PRESSBREITE <= (prod_r.T_NENNBREITE + 10)  then
      
        --Info schreiben abgrenzung
        PKG_UTIL_APL.insert_abgrenzung(prod_r,i_programm_name);
                
        --ablaengen
        i_gruppen_id := 10;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'468',1,p_array,'614',i_programm);--ablaengen
        PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
        
        --stirnen
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,'655',i_programm);--stirnen
        PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);
      
        if prod_r.T_K1KA582 = ('91') then -- schlitzen
            i_gruppen_id := 20;
            i_programm := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'380',1,p_array,'645',i_programm);--schlitzen
            if prod_r.T_ZEICHNUNGSNR is not null or trim(prod_r.T_ZEICHNUNGSNR) is not null then
                i_gruppen_id := 30;
                i_programm := i_programm_name || i_gruppen_id;
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'380',2,p_array,'645',i_programm);--laut Zeichnung
            end if;
            PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);
        end if;
       
        find := true;
        p_isRevision_abblasen := false;
  else
        find := false;
  end if;
  
    EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.BON_0 '|| ' Abgrenzung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB(TEXT) VALUES(sqlerror);
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.BON_0 APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror  
        );
  END BON_0;
  

--Kunsthartinnenzone
PROCEDURE KA526_8(
    prod_r produktions_record)
AS
  i_gruppen_id    NUMBER DEFAULT 0;
  i_programm_name VARCHAR2(32) DEFAULT 'KA526_8 ';
  i_programm      VARCHAR2(32);
  p_array PKG_UTIL_APL.array_var_text_time;
BEGIN
  --Kunsthartinnenzone
  IF prod_r.T_KA526 = '8' THEN
    
  
    p_array        := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
    --abblasen
    i_gruppen_id := 10;
    i_programm   := i_programm_name || i_gruppen_id;
    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);--abblasen
    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',1,p_array,'594',i_programm);--traenken
    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',2,p_array,'594',i_programm);--traenken
    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',1,p_array,'594',i_programm);--trocknen/ Luft
    p_array(1) := '24';
    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',3,p_array,'594',i_programm);--dauer trocknen
    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'386',1,p_array,'595',i_programm);--aushaerten
    p_array(1) := '12';
    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'386',2,p_array,'595',i_programm);--dauer aushaerten
    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'386',3,p_array,'595',i_programm);--im Ofen
  END IF;
EXCEPTION
WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
  sqlerror :='ERROR -->PKG_WERK2.KA526_8 ->>' || SQLERRM;
  INSERT INTO LOGTAB
    (TEXT
    ) VALUES
    (sqlerror
    );
END;


--bandagieren
PROCEDURE bandagieren(
    prod_r produktions_record)
AS
  i_gruppen_id    NUMBER DEFAULT 0;
  i_programm_name VARCHAR2(32) DEFAULT 'bandagieren ';
  i_programm      VARCHAR2(32);
  i_arbeitsplatz varchar2(3);
  p_array PKG_UTIL_APL.array_var_text_time;
BEGIN
  --bandagieren
  IF trim(prod_r.T_BANDAGEN_ANZAHL) is not null and  prod_r.T_BANDAGEN_ANZAHL > '0' THEN
    
    p_array        := PKG_UTIL_APL.array_var_text_time('0','0','0','0','0');
    
    p_array(1) := prod_r.T_BANDAGEN_ANZAHL;
    
    if prod_r.T_NENNBREITE <= 50 then
         p_array(2) := '6';
    elsif prod_r.T_NENNBREITE <= 79 then
         p_array(2) := '9';
    elsif prod_r.T_NENNBREITE <= 100 then
         p_array(2) := '15';    
    else
         p_array(2) := '15';    
    end if;
    
    IF trim(prod_r.T_BANDAGEN_BREITE) is not null and  prod_r.T_BANDAGEN_BREITE > '00' THEN
        p_array(2) := trim(prod_r.T_BANDAGEN_BREITE); 
    end if;
    
    if prod_r.T_NENNDURCHMESSER >= 65 and  prod_r.T_NENNDURCHMESSER <= 250 and prod_r.T_NENNBREITE <=100 then
         i_arbeitsplatz := '505';
    elsif prod_r.T_NENNDURCHMESSER between 150 and 450 and prod_r.T_NENNBREITE  between 10 and 160 then
        i_arbeitsplatz := '515';
    elsif (prod_r.T_NENNDURCHMESSER > 450 and  prod_r.T_NENNDURCHMESSER <= 600) and prod_r.T_NENNBREITE <=150 then
        i_arbeitsplatz := '521';
    else
         i_arbeitsplatz := '   ';
         raise ABGRENZUNG_FEHLER;
    end if;
   
    
    if i_arbeitsplatz = '   ' then
        raise ABGRENZUNG_FEHLER;
    end if;
    
    --
    i_gruppen_id := i_gruppen_id||''||100;
    i_programm   := i_programm_name || i_gruppen_id;
    --abblasen
    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);
    
    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'390',1,p_array,i_arbeitsplatz,i_programm);--bandagieren
    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'390',2,p_array,i_arbeitsplatz,i_programm);--bandagieren
    
   
  END IF;

EXCEPTION
 WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.bandagieren Abgrenzung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
  sqlerror :='ERROR -->PKG_WERK2.bandagieren ->>' || SQLERRM;
  INSERT INTO LOGTAB
    (TEXT
    ) VALUES
    (sqlerror
    );
END bandagieren;


--Bakelit_traenken_spritzen
PROCEDURE traenken(
    prod_r produktions_record)
AS
  i_gruppen_id    NUMBER DEFAULT 0;
  i_programm_name VARCHAR2(32) DEFAULT 'traenken ';
  i_programm      VARCHAR2(32);
  p_array PKG_UTIL_APL.array_var_text_time;
BEGIN
  
  p_array        := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  
  --traenken
  IF prod_r.T_KA526 = '1' or  (prod_r.T_KA526 ='8' and prod_r.T_KA5214 = 'W') THEN
   
      --abblasen
      i_gruppen_id := 10;
      i_programm   := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);--abblasen
      
      if prod_r.T_ka526='1' and prod_r.T_ka5214=' ' then --fehler, keine Tränkungart angegeben
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',1,p_array,'594',i_programm);--traenken
           p_array(1) := 'Fehler Tränkungsart nicht angegeben';
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'ERR',1,p_array,'594',i_programm);--ERROR
           --Fehler Abgrenzung
          raise ABGRENZUNG_FEHLER;
          
      end if;    
      if  prod_r.T_KA5214 = 'E' THEN
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',1,p_array,'594',i_programm);--traenken
          p_array(1) := '10';
          p_array(2) := '90';
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',8,p_array,'594',i_programm);--
      elsif prod_r.T_KA5214 = 'G' THEN
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',1,p_array,'594',i_programm);--traenken
          p_array(1) := '20';
          p_array(2) := '80';
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',8,p_array,'594',i_programm);--
      elsif prod_r.T_KA5214 = 'I' THEN
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',1,p_array,'594',i_programm);--traenken
          p_array(1) := '30';
          p_array(2) := '70';
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',8,p_array,'594',i_programm);--
      elsif prod_r.T_KA5214 = 'W' THEN --wachs
          if prod_r.T_NENNDURCHMESSER<=300 then  
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',1,p_array,'676',i_programm);--traenken
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',9,p_array,'676',i_programm);--wachs
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',1,p_array,'676',i_programm);--trocknen in HST Abteilung
              p_array(1) := '12'; --h
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',3,p_array,'676',i_programm);--bei Luft in HST Abteilung
         /* else
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',1,p_array,'594',i_programm);--traenken
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',9,p_array,'594',i_programm);--wachs
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',1,p_array,'594',i_programm);--trocknen
              p_array(1) := '12'; --h
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',3,p_array,'594',i_programm);--bei Luft*/
          end if;
          
      end if;
  elsif  prod_r.T_KA526 = '3' THEN
      i_gruppen_id := 20;
      i_programm   := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);--abblasen
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',1,p_array,'594',i_programm);--kanten härten
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',2,p_array,'594',i_programm);--tränken
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',4,p_array,'594',i_programm);--einseitig
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',1,p_array,'595',i_programm);--trocknen
      p_array(1) := '170';
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',4,p_array,'595',i_programm);--bei Grad 170
      
  elsif  prod_r.T_KA526 = '5' THEN
      i_gruppen_id := 20;
      i_programm   := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);--abblasen
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',1,p_array,'594',i_programm);--kanten härten
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',2,p_array,'594',i_programm);--tränken
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',5,p_array,'594',i_programm);--zweiseitig
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',1,p_array,'595',i_programm);--trocknen
      p_array(1) := '170';
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',4,p_array,'595',i_programm);--bei Grad 170
  elsif  prod_r.T_KA526 = '6' THEN
      i_gruppen_id := 20;
      i_programm   := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);--abblasen
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',1,p_array,'594',i_programm);--kanten härten
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',3,p_array,'594',i_programm);--tränken
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',4,p_array,'594',i_programm);--einseitig
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',1,p_array,'595',i_programm);--trocknen
      p_array(1) := '170';
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',4,p_array,'595',i_programm);--bei Grad 170

  elsif  prod_r.T_KA526 = '7' THEN
      i_gruppen_id := 20;
      i_programm   := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);--abblasen
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',1,p_array,'594',i_programm);--kanten härten
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',3,p_array,'594',i_programm);--tränken
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',5,p_array,'594',i_programm);--zweiseitig
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',1,p_array,'595',i_programm);--trocknen
      p_array(1) := '170';
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',4,p_array,'595',i_programm);--bei Grad 170

  elsif  prod_r.T_KA526 = '9' THEN
      i_gruppen_id := 20;
      i_programm   := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);--abblasen
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',1,p_array,'594',i_programm);--kanten härten
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',2,p_array,'594',i_programm);--tränken
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'490',6,p_array,'594',i_programm);--Umfläche
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',1,p_array,'595',i_programm);--trocknen
      p_array(1) := '170';
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',4,p_array,'595',i_programm);--bei Grad 170
       
  END IF;
EXCEPTION
 WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.traenken Abgrenzung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
  sqlerror :='ERROR -->PKG_WERK2.traenken APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
  INSERT INTO LOGTAB
    (TEXT
    ) VALUES
    (sqlerror
    );
END traenken;


  /*
* Ablauf revision
*
*
*/
  PROCEDURE signieren_flanschen(
      prod_r produktions_record,
      p_arbeitsplatz varchar2) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'signieren_flanschen ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3);
   i_flansch_bedruckt boolean default false;
   p_array PKG_UTIL_APL.array_var_text_time;
   
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
   
  If prod_r.T_KA5212 = 'S' then
      --flansche nicht bedrucken, nur Signieren
      null; 
      
  elsif (prod_r.T_NENNDURCHMESSER>=80 and prod_r.T_NENNDURCHMESSER<300 and
        prod_r.T_NENNBREITE >=6 and  prod_r.T_NENNBREITE<=100) or
        (prod_r.T_NENNDURCHMESSER>=300 and prod_r.T_NENNDURCHMESSER<=450 and
        prod_r.T_NENNBREITE >=15 and  prod_r.T_NENNBREITE<=100 and
        prod_r.T_KORNGROESSE <= 240)then  --Flansche Ablauf
        
        if prod_r.T_METER_JE_SEC <= 50 or
          (prod_r.T_METER_JE_SEC <= 50 and
          prod_r.T_NENNDURCHMESSER<300) or
           (prod_r.T_METER_JE_SEC <= 80 and
          prod_r.T_NENNDURCHMESSER<300 and prod_r.T_KUNDENNUMMER='57058') then
          
          i_gruppen_id := 100;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'580',1,p_array,'745',i_programm); --drucken
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'580',2,p_array,'745',i_programm); --flansche bedrucken
          i_flansch_bedruckt := true;
        end if;
  end if;
          
  
  
  if prod_r.T_BEZEICHNUNG = 'HHS' and  prod_r.T_KA5212 = 'F' then
      i_gruppen_id := 300;
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'592',1,p_array,'740',i_programm); --flanschen
  elsif prod_r.T_BEZEICHNUNG = 'SLS' and  prod_r.T_KA5212 = 'F' then
      i_gruppen_id := 310;
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'592',1,p_array,p_arbeitsplatz,i_programm); --flanschen
  elsif i_flansch_bedruckt then
      i_gruppen_id := 320;
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'592',1,p_array,p_arbeitsplatz,i_programm); --flanschen
  else -- signieren ab hier:
        if prod_r.T_BEZEICHNUNG = 'HHS' and prod_r.T_KA5212 = 'S'   then
          i_gruppen_id := 340;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'591',1,p_array,'740',i_programm); --signieren
        elsif prod_r.T_BEZEICHNUNG = 'SLS' and prod_r.T_KA5212 = 'S'  then
          i_gruppen_id := 350;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'591',1,p_array,p_arbeitsplatz,i_programm); --signieren
        else
          i_gruppen_id := 360;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'591',1,p_array,p_arbeitsplatz,i_programm); --signieren
        end if;
  end if;
  

   
   
    EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.signieren_flanschen Abgrenzung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.signieren_flanschen APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END signieren_flanschen;
  
  
  
  
  
/*
* Ablauf 
*
*
*/
  PROCEDURE austreichen_bohrung(
      prod_r produktions_record) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'austreichen_bohrung ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3);
   i_flansch_bedruckt boolean default false;
   p_array PKG_UTIL_APL.array_var_text_time;
   
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  
  if prod_r.T_BEZEICHNUNG  = 'SLS' then
       
      If    prod_r.T_KA529 = '5' then
          i_gruppen_id := 100;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',1,p_array,'717',i_programm); --tränken
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',4,p_array,'717',i_programm); --Bohrung mit Wachs
      elsIf prod_r.T_KA529 = 'B' then
          i_gruppen_id := 110;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',1,p_array,'676',i_programm); --tränken
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',5,p_array,'717',i_programm); --Bohrung mit Schwefel
      elsIf prod_r.T_KA529 = 'C' then
          i_gruppen_id := 120;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',1,p_array,'594',i_programm); --tränken
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',6,p_array,'717',i_programm); --Bohrung mit BAK
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',1,p_array,'595',i_programm); --trocknen
      elsIf prod_r.T_KA529 = 'K' then
          i_gruppen_id := 130;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',1,p_array,'594',i_programm); --tränken 
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'500',7,p_array,'717',i_programm); --Bohrung mit Rütapox
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',1,p_array,'595',i_programm); --trocknen
      end if;
      
  end if;              
  
  
  
   
   
    EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.austreichen_bohrung Abgrenzung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.austreichen_bohrung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END austreichen_bohrung;
  

  
    /*
* Ablauf 
*
*
*/
  PROCEDURE ausspritzen_bohrung(
      prod_r produktions_record) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'ausspritzen_bohrung ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3);
   i_flansch_bedruckt boolean default false;
   p_array PKG_UTIL_APL.array_var_text_time;
   i_text varchar2(1024);
   
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  

  
  if PKG_UTIL_APL.is_ausspritzen_bohrung(prod_r) then
            -- DBMS_OUTPUT.PUT_LINE( 'ausspritzen_bohrung -->' ||2);
            if ((power(prod_r.T_PRESSBOHRUNG,2) - power(prod_r.T_NENNBOHRUNG,2)) *0.785 * (prod_r.T_NENNBREITE-prod_r.T_AUSSPARUNG1TIEFE)/1000) < 13 then
              --jetzt Bohrung ausspritzen
                i_gruppen_id := 100;
                i_programm := i_programm_name || i_gruppen_id;
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'340',1,p_array,'551',i_programm); --Bohrung ausspritzen 
                PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);
            else
              i_text := round(((power(prod_r.T_PRESSBOHRUNG,2) - power(prod_r.T_NENNBOHRUNG,2)) *0.785 * (prod_r.T_NENNBREITE-prod_r.T_AUSSPARUNG1TIEFE)/1000),2) || ' ccm ist größer als 13ccm, Volumen zu groß';
              p_array(1) :=  substr( i_text,1,40);
              i_gruppen_id := 120;
              i_programm := i_programm_name || i_gruppen_id;
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'340',1,p_array,'551',i_programm); --Bohrung ausspritzen 
              PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'ERR',1,p_array,'551',i_programm); --Bohrung ausspritzen 
              raise ABGRENZUNG_FEHLER;
            end if;   
  end if;
    
   
    EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.ausspritzen_bohrung APLNr:'||prod_r.T_ARBEITSPLANNUMMER|| ' Abgrenzung ->>' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.ausspritzen_bohrung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END ausspritzen_bohrung;
  
   /*
* Ablauf 
*
*
reduring setzten  ist in der Revision eingebaut


  PROCEDURE reduring_bohrung(
      prod_r produktions_record) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'reduring_bohrung ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3);
   i_flansch_bedruckt boolean default false;
   p_array PKG_UTIL_APL.array_var_text_time;
   
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  
  if prod_r.T_KA523 = '2' then
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'340',1,p_array,'551',i_programm); --Bohrung reduzieren 
  end if;              
  
  
  EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.reduring_bohrung Abgrenzung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.reduring_bohrung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END reduring_bohrung;
*/
/*
*
*
*
*
*/
PROCEDURE trocknen
  (
    prod_r produktions_record
  )
IS
  i_programm_name VARCHAR2(32) DEFAULT 'trocknen ';
  i_programm      VARCHAR2(32);
  i_gruppen_id    NUMBER DEFAULT 0;
  i_arbeitsplatz   varchar2(3);
  p_array PKG_UTIL_APL.array_var_text_time;
BEGIN
    
    p_array              := PKG_UTIL_APL.array_var_text_time('0','0','0','0','0');
    
  --DBMS_OUTPUT.PUT_LINE( '    trocknen-->' || SQLERRM||' Nr '||i_gruppen_id);
  
  
  
    if p_isTrocken = false then
        if prod_r.T_BEZEICHNUNG in ('HST','SLK') then
            i_gruppen_id := 202;
            i_programm   := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'470',1,p_array,'672',i_programm);
            if prod_r.T_CHARAKTERISTIKA = 'B' then
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'470',2,p_array,'672',i_programm);
            else
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'470',4,p_array,'672',i_programm);
            end if;
        else
            i_gruppen_id := 300;
            i_programm   := i_programm_name || i_gruppen_id;
            PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',1,p_array,'672',i_programm); --trocknen
            if prod_r.T_CHARAKTERISTIKA = 'B' then
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',6,p_array,'672',i_programm);
            else
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'384',5,p_array,'672',i_programm);
            end if;
        end if;
  
       
        p_isTrocken := true;
    end if;
   
    EXCEPTION
WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE( 'ERROR trocknen-->' || SQLERRM||' Nr '||i_gruppen_id);
  sqlerror :='ERROR -->PKG_HST.trocknen APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM||' Nr '||i_gruppen_id;
  INSERT INTO LOGTAB
    (TEXT
    ) VALUES
    (sqlerror
    );
    
    end;
  
/*
* Ablauf schwefel
*
*
*/
  PROCEDURE schwefel(
      prod_r produktions_record) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'schwefel ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3);
   i_flansch_bedruckt boolean default false;
   p_array PKG_UTIL_APL.array_var_text_time;
   
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  
  if prod_r.T_BEZEICHNUNG  in ( 'SLS','HHS') then
       
      If    prod_r.T_KA526 = '2' then
          if p_isTrocken= false then
              trocknen(prod_r); --trocknen vorher
          end if;
          i_gruppen_id := 100;
          i_programm := i_programm_name || i_gruppen_id;
          --immer vorher aufheizen
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'475',1,p_array,'679',i_programm);
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'475',5,p_array,'679',i_programm);
          --schwefeln
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'480',1,p_array,'676',i_programm);
      end if;
  end if;              
  
   
    EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.schwefel Abgrenzung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.schwefel APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END schwefel;




 /*
* Ablauf revision
*
*
*/
  PROCEDURE cnc(
      prod_r  produktions_record,
      find OUT BOOLEAN) AS
      
      
   i_gruppen_id number default 0;
   i__planieren_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'cnc ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3); 
   p_array PKG_UTIL_APL.array_var_text_time;
   b_vorplanieren boolean default false;
   
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  find := false;
  
  --Ablauf CNC mit seitliche Kitten
  seitlich_kitt(prod_r,find);
  if find = true then
      return;
  end if;
  
  
  --normaler Ablauf CNC
   -- Abgrenzung CNC oder normal planieren
  if  ( prod_r.T_PRESSBREITE > 270 or prod_r.T_KORNGROESSE >= 150 or  prod_r.T_ANWENDUNGSSCHLUESSEL ='26') then
      b_vorplanieren := true;
  else
      b_vorplanieren := false; 
  end if;
  
  
  --Werte für vorplanieren
if b_vorplanieren then
  if  prod_r.T_ANWENDUNGSSCHLUESSEL ='26' then
          i_arbeitsplatz := PKG_UTIL_APL.getCNC_AP(prod_r);  -- kein vorplanieren vor CNC, sonderablauf Kunsthartinnenzone
          if (i_arbeitsplatz is null or trim(i_arbeitsplatz) is null)  then-- kein CNC arbeitsplatz
              return;
          end if;
          i_arbeitsplatz := PKG_UTIL_APL.getPlanierBank_AP(prod_r,i__planieren_gruppen_id );
          i_gruppen_id := 90;
          i_programm := i_programm_name || i_gruppen_id||' Planier:'||i__planieren_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',1,p_array,i_arbeitsplatz,i_programm);--vorplanieren
          p_array(1) := '2';
          p_array(2) := to_char(prod_r.T_NENNBREITE + p_array(1),'9G990D90');
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',2,p_array,i_arbeitsplatz,i_programm);-- +2mm
          if prod_r.T_KA524 = '9' then
              i_gruppen_id := 110;
              i_programm := i_programm_name || i_gruppen_id;
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'538',i_programm);--feinschleifen
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',5,p_array,'538',i_programm);--feinschleifen
          end if;
  elsif  (prod_r.T_PRESSBREITE - prod_r.T_NENNBREITE) > 3 or   prod_r.T_KA524='9' then
  
        i_arbeitsplatz := PKG_UTIL_APL.getCNC_AP(prod_r);  -- kein vorplanieren vor CNC, sonderablauf Kunsthartinnenzone
        if (i_arbeitsplatz is null or trim(i_arbeitsplatz) is null)  and prod_r.T_KA526 = '8' then-- kein CNC arbeitsplatz
            return;
        end if;
  
      if (prod_r.T_BN_MAX_TOL-prod_r.T_BN_MIN_TOL) <= 0.2 and prod_r.T_HAERTE > 'J' and prod_r.T_CHARAKTERISTIKA = 'V'  then
           -- naßschleifen wegen Haerte
          if prod_r.T_NENNDURCHMESSER >=100 and  prod_r.T_NENNDURCHMESSER <= 500 and
             prod_r.T_NENNBREITE>=3 and prod_r.T_NENNBREITE <=400 then
              i_gruppen_id := 120;
              i_programm := i_programm_name || i_gruppen_id;
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);--abblasen
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'624',i_programm);--feinschleifen
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',5,p_array,'624',i_programm);--feinschleifen Planfläche
              PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
              p_isTrocken := false;
              trocknen(prod_r); --trocknen 
          else
              --Fehler Abgrenzung
              --raise ABGRENZUNG_FEHLER;
              null;
          end if;           
      else
          --Abgrenzung Arbeitsplatz CNC aufrufen , kein CNC Arbeitsplatz, dann kein Vorplanieren!!!!       
          i_arbeitsplatz := PKG_UTIL_APL.getCNC_AP(prod_r);  
          if prod_r.T_KA526 = '8' or
             ( i_arbeitsplatz<>'   ' and prod_r.T_KA524 = '9') or
             ( i_arbeitsplatz<>'   ' and prod_r.T_KORNGROESSE < 150) then
              -- Vorplanieren erforderlich
              --if (i_arbeitsplatz is null or i_arbeitsplatz  = '   ') and prod_r. then  --kein Arbeitsplatz CNC gefunden, keien CNC Bearbeitung
                
                i_arbeitsplatz := PKG_UTIL_APL.getPlanierBank_AP(prod_r,i__planieren_gruppen_id );
                i_gruppen_id := 100;
                i_programm := i_programm_name || i_gruppen_id||' Planier:'||i__planieren_gruppen_id;
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',1,p_array,i_arbeitsplatz,i_programm);--vorplanieren
                if (prod_r.T_BN_MAX_TOL-prod_r.T_BN_MIN_TOL) <= 0.4 then
                    p_array(1) := '1,5';
                else
                    p_array(1) := '1';
                end if;
                p_array(2) := to_char(prod_r.T_NENNBREITE + to_number(p_array(1)),'9G990D90');
                --prod_r.T_B_vorplanier := prod_r.T_NENNBREITE + to_number(p_array(1));
                PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',2,p_array,i_arbeitsplatz,i_programm);-- +1mm
                if prod_r.T_KA524 = '9'   then
                    i_gruppen_id := 110;
                    
                    i_programm := i_programm_name || i_gruppen_id;
                    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,PKG_UTIL_APL.getCNC_AP(prod_r),i_programm);--feinschleifen
                    PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',5,p_array,PKG_UTIL_APL.getCNC_AP(prod_r),i_programm);--feinschleifen Planfläche
                end if;
          
          end if; --if vorplanieren
      end if;
  end if;
end if; --vorplanieren



  --Abgrenzung Arbeitsplatz CNC aufrufen        
  i_arbeitsplatz := PKG_UTIL_APL.getCNC_AP(prod_r);   
  if i_arbeitsplatz is null or i_arbeitsplatz  = '   ' then  --kein Arbeitsplatz CNC gefunden, keine CNC Bearbeitung
      return;
  end if;
   DBMS_OUTPUT.PUT_LINE( 'CNC -->'  );
  --Info schreiben abgrenzung
  PKG_UTIL_APL.insert_abgrenzung(prod_r,i_programm_name);
      
  --  besonderer Abgrenzung 
  if i_arbeitsplatz = '538' and prod_r.T_PRESSBREITE > 256 then
      i_gruppen_id := 200;
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',1,p_array,i_arbeitsplatz,i_programm);--
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',7,p_array,i_arbeitsplatz,i_programm);--1. Seite planieren
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',8,p_array,i_arbeitsplatz,i_programm);--an stirnen und bohren
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',9,p_array,i_arbeitsplatz,i_programm);--hinterdrehen
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',10,p_array,i_arbeitsplatz,i_programm);--2. Seite planieren
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',11,p_array,i_arbeitsplatz,i_programm);--rest stirnen und bohren
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
      find := true;
      p_isCNCbearbeitet := true;
  elsif i_arbeitsplatz = '539' and  prod_r.T_PRESSBREITE > 310 then
      i_gruppen_id := 210;
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',1,p_array,i_arbeitsplatz,i_programm);--
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',7,p_array,i_arbeitsplatz,i_programm);--1. Seite
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',8,p_array,i_arbeitsplatz,i_programm);--planieren
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',9,p_array,i_arbeitsplatz,i_programm);--an stirnen und bohren
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',10,p_array,i_arbeitsplatz,i_programm);--hinterdrehen
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',11,p_array,i_arbeitsplatz,i_programm);--2. Seite
      --PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',1,p_array,i_arbeitsplatz,i_programm);--planieren
      --PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'321',1,p_array,i_arbeitsplatz,i_programm);--rest stirnen und bohren
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
      find := true;
      p_isCNCbearbeitet := true;
  elsif prod_r.T_PRESSDURCHMESSER1> 900 and prod_r.T_ANWENDUNGSSCHLUESSEL <>'26' then
      i_gruppen_id := 310;
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,'547',i_programm);--planieren
      PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm); 
      if prod_r.T_PRESSBOHRUNG >= 125 then
          i_gruppen_id := 320;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,'539',i_programm);--stirnen
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'330',1,p_array,'538',i_programm);--bohren
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
      else
          i_gruppen_id := 330;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,'536',i_programm);--stirnen
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'330',1,p_array,'536',i_programm);--bohren
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
      end if;
      find := true;
      p_isCNCbearbeitet := true;
  end if;
  
  -- Sonderabgrenzung kein APlan gefunden, dann hier weiter..
  if not find then --regulaere CNC
     if trim(prod_r.T_FEPAFORM) in ( '1','2') then
        i_gruppen_id := 400;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'301',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'300',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        find := true;
        p_isCNCbearbeitet := true;
     elsif trim(prod_r.T_FEPAFORM) in ( '3') then
        i_gruppen_id := 410;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'301',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'300',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'370',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        find := true;
        p_isCNCbearbeitet := true;
    elsif trim(prod_r.T_FEPAFORM) in ( '5','5S','6') then
        i_gruppen_id := 420;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'300',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'302',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        find := true;
        p_isCNCbearbeitet := true;
    elsif trim(prod_r.T_FEPAFORM) in ( '7','9') then
        i_gruppen_id := 430;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'302',1,p_array,i_arbeitsplatz,i_programm);--
        --PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        --PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);
        --PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
        --PKG_UTIL_APL.setToleranz('AUSSPAR',v_aplsatz_obj,prod_r,i_programm);
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'303',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        --PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);
        --PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);
        --PKG_UTIL_APL.setToleranz('AUSSPAR',v_aplsatz_obj,prod_r,i_programm);
        
        find := true;
        p_isCNCbearbeitet := true;
    elsif trim(prod_r.T_FEPAFORM) in ( '20','23') then
        i_gruppen_id := 440;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'300',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'305',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        find := true;
        p_isCNCbearbeitet := true;
    elsif trim(prod_r.T_FEPAFORM) in ( '25N') then
        i_gruppen_id := 450;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'305',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'308',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        find := true;
        p_isCNCbearbeitet := true;
    elsif trim(prod_r.T_FEPAFORM) in ( '20N') then
        i_gruppen_id := 460;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'300',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'307',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        find := true;
        p_isCNCbearbeitet := true;
    elsif trim(prod_r.T_FEPAFORM) in ( '22N') then
        i_gruppen_id := 470;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'303',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'307',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        find := true;
        p_isCNCbearbeitet := true;
    elsif trim(prod_r.T_FEPAFORM) in ( '21N') then
        i_gruppen_id := 480;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'307',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'308',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        find := true;
        p_isCNCbearbeitet := true;
    elsif trim(prod_r.T_FEPAFORM) in ( '22','24') then
        i_gruppen_id := 490;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'303',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'305',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        find := true;
        p_isCNCbearbeitet := true;
    elsif trim(prod_r.T_FEPAFORM) in ( '35') then
        i_gruppen_id := 500;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'304',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'309',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        find := true;
        p_isCNCbearbeitet := true;
    elsif trim(prod_r.T_FEPAFORM) in ( '21','25') then
        i_gruppen_id := 510;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'305',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'306',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        find := true;
        p_isCNCbearbeitet := true;
    elsif trim(prod_r.T_FEPAFORM) in ( '36','37') then
        i_gruppen_id := 520;
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'359',1,p_array,i_arbeitsplatz,i_programm);--
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
        find := true;
        p_isCNCbearbeitet := true;
    else
        --Fehler Abgrenzung
        raise ABGRENZUNG_FEHLER;
    end if;
  end if;
  
  
   
    EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.cnc AplanNr:'||prod_r.t_ARBEITSPLANNUMMER||' Abgrenzung ->>' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE(i_gruppen_id|| 'ERROR -->' || SQLERRM);
      sqlerror := i_gruppen_id||' ERROR -->PKG_WERK2.cnc ->>' || SQLERRM ||prod_r.t_ARBEITSPLANNUMMER;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END cnc;



 /*
* Ablauf form_profil
*
*
*/
  PROCEDURE form_profil(
      prod_r produktions_record) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'form_profil ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3);
   i_flansch_bedruckt boolean default false;
   p_array PKG_UTIL_APL.array_var_text_time;
   
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
   
  --Profil oder Form vorhanden?, wenn nicht return
  if not PKG_UTIL_APL.isFormProfil(prod_r) or p_isForm_Profil  then
      return;
  end if;
     
  -- DBMS_OUTPUT.PUT_LINE( 'form_profil prüfen -->' || SQLERRM);
  -- ausnahme für Kugellagerlaufbahnscheiben  wenn nur Absatz angebracht wurde, dann keine weitere Form und Profil
  if p_isAbsatz_angebracht  and  trim(prod_r.T_PROFIL)   is  null   and trim(prod_r.T_K2KA582)  is  null  then
      return;
  end if;
    DBMS_OUTPUT.PUT_LINE( 'form_profil -->' || SQLERRM);

  -- Abgrenzung bei BOP=0
  if prod_r.T_PRESSBOHRUNG = 0 then
      if prod_r.T_BEZEICHNUNG = 'SLS' and prod_R.T_NENNDURCHMESSER<= 65 then
          i_gruppen_id := 100;
          i_arbeitsplatz :='524';
      elsif  prod_R.T_NENNDURCHMESSER<= 300 then
          i_gruppen_id := 110;
          i_arbeitsplatz :='516';
      elsif prod_R.T_NENNDURCHMESSER<= 410 then
          i_gruppen_id := 120;
          i_arbeitsplatz :='515';
      elsif prod_R.T_NENNDURCHMESSER<= 650 then
          i_gruppen_id := 130;
          i_arbeitsplatz :='535';
      end if;
      
  --Honringe      
  elsif prod_r.T_KA5213 in( '1','2') then
      i_gruppen_id := 150;
      i_arbeitsplatz :='626';
      
  --Abgrenzung Eisenteller
  elsif prod_r.T_KA524 = '1' then
      if prod_R.T_NENNDURCHMESSER<= 400 then
          i_gruppen_id := 200;
          i_arbeitsplatz :='521';
      elsif  prod_R.T_NENNDURCHMESSER<= 800 then
          i_gruppen_id := 210;
          i_arbeitsplatz :='535';
      else
          i_gruppen_id := 220;
          i_arbeitsplatz :='536';
      end if;
  --
  elsif prod_r.T_K1KA582 in ('34','36') then
          i_gruppen_id := 300;
          i_arbeitsplatz :='524';
  elsif prod_r.T_PRESSDURCHMESSER1 > 615.7 and prod_r.T_K1KA582<>'85' then
      if prod_R.T_K1KA582 in ('50','66','73','74','75') and i_bohren_ap = '535' then  --- nur bei bohren auf der 535
          i_gruppen_id := 400;
          i_arbeitsplatz :='535';
      elsif prod_R.T_K1KA582 in ('50','73','75')  and i_bohren_ap = '536' then  --- nur bei bohren auf der 536
          i_gruppen_id := 410;
          i_arbeitsplatz :='536';
       elsif prod_R.T_K1KA582 in ('41','43','46','55','60','61','62','63','64','67','91') or
             (prod_r.T_NENNDURCHMESSER <=925 and trim(prod_r.T_PROFIL) is not null  ) then  --- nur bei bohren auf der 536
          i_gruppen_id := 420;
          i_arbeitsplatz :='535';
      else
          i_gruppen_id := 430;
          i_arbeitsplatz :='536';
      end if;

  elsif prod_r.T_PRESSDURCHMESSER1 >= 410.5 then
      if (prod_r.T_KA522 in ('1','2') or prod_r.T_KA524='2' ) and trim(prod_R.T_K1KA582) is not null and prod_R.T_K1KA582<>'85' then
          i_gruppen_id := 500;
          i_arbeitsplatz :='526';
      elsif prod_r.T_NENNBREITE <= 125 and prod_r.T_NENNDURCHMESSER > 600 then
          i_gruppen_id := 510;
          i_arbeitsplatz :='526';
      elsif prod_r.T_NENNBREITE <= 125  then
          i_gruppen_id := 520;
          i_arbeitsplatz :='522';
      elsif prod_R.T_K1KA582 in ('60','61','62','63','64','91') or prod_R.T_K1KA582='61' or trim(prod_r.T_PROFIL) is not null then
          i_gruppen_id := 530;
          i_arbeitsplatz :='526';
      else
          i_gruppen_id := 540;
          i_arbeitsplatz :='536';
      end if;
  elsif prod_r.T_PRESSDURCHMESSER1 >= 300 then
      if  prod_R.T_K1KA582='60' and ((prod_r.T_K2FELD1KA58-prod_r.T_NENNBOHRUNG) <= 20 or (prod_r.T_K2FELD2KA58-prod_r.T_NENNBOHRUNG) <= 20) then
          i_gruppen_id := 600;
          i_arbeitsplatz :='526';
      elsif prod_r.T_NENNBREITE <= 20 and prod_r.T_PROFIL in ('F','E','G') then
          i_gruppen_id := 610;
          i_arbeitsplatz :='521';
      elsif prod_r.T_NENNBREITE <= 20 and prod_r.T_K1KA582 ='55'  then
          i_gruppen_id := 620;
          i_arbeitsplatz :='521';
      else
          i_gruppen_id := 630;
          i_arbeitsplatz :='532';
      end if;
  elsif prod_r.T_PRESSDURCHMESSER1 > 70 then
       if  (prod_r.T_NENNBREITE <= 8 and trim(prod_r.T_PROFIL) is not null) or
           (prod_R.T_NENNBREITE <= 6 and (prod_r.T_PROFIL='C'  or prod_r.T_K1KA582 = '41')) or 
           prod_r.T_PROFIL in ('F','L')  or 
           prod_r.T_K1KA582 in ('48','55','56') then
          i_gruppen_id := 700;
          i_arbeitsplatz :='521';
      elsif prod_r.T_PRESSDURCHMESSER1 <= 160 or  
           (prod_r.T_PRESSDURCHMESSER1 <= 200 and prod_r.T_PROFIL = 'C') or 
            prod_r.T_K1KA582 = '34' then
          i_gruppen_id := 710;
          i_arbeitsplatz :='524';
      elsif  prod_R.T_K1KA582='60' and prod_r.T_KA524 <> '3' and ( (prod_r.T_K2FELD1KA58 > 0 and (prod_r.T_K2FELD1KA58-prod_r.T_NENNBOHRUNG) <= 20) or 
                                                                   ( prod_r.T_K2FELD2KA58 > 0 and (prod_r.T_K2FELD2KA58-prod_r.T_NENNBOHRUNG) <= 20)) then
          i_gruppen_id := 720;
          i_arbeitsplatz :='515';
       elsif  prod_R.T_K1KA582='91' and prod_r.T_K2FELD1KA58=1 and prod_r.T_KA527 <> '5' then
          i_gruppen_id := 730;
          i_arbeitsplatz :='658';
      else
          i_gruppen_id := 740;
          i_arbeitsplatz :='522';
      end if;
  else
      if prod_r.T_K1FELD1KA58 in (2.6,3.9,4.4,4.5,5,7.2) then
          i_gruppen_id := 800;
          i_arbeitsplatz :='634';
      elsif prod_r.T_NENNDURCHMESSER >20 and prod_r.T_NENNDURCHMESSER < 400 and  prod_r.T_NENNBREITE > 25 and  prod_r.T_NENNBREITE <150 and
        prod_r.T_K1FELD1KA58>=12.5 and prod_r.T_K1FELD1KA58<=75 then
          i_gruppen_id := 810;
          i_arbeitsplatz :='626';
      elsif  prod_r.T_K1KA582 in ('60','61','62','64','66','67','68' ) then
          i_gruppen_id := 820;
          i_arbeitsplatz :='626';
       elsif  prod_R.T_K1KA582='91' and prod_r.T_K1FELD1KA58 in (1,2,3) then
          i_gruppen_id := 830;
          i_arbeitsplatz :='524';
      else
       -- DBMS_OUTPUT.PUT_LINE( 'form_profil -->' || SQLERRM);
           --Fehler Abgrenzung
        raise ABGRENZUNG_FEHLER; 
      end if;
  end if;
 
 
  if  i_gruppen_id > 0 then
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'370',1,p_array,i_arbeitsplatz,i_programm);--Profil und Formbearbeitung
      
      if prod_r.T_KA5213 = '2' then
          i_gruppen_id := 991;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'370',3,p_array,i_arbeitsplatz,i_programm);--Profilrolle naß
      end if;
      
      if prod_r.T_ZEICHNUNGSNR is not null or trim(prod_r.T_ZEICHNUNGSNR) is not null then
          i_gruppen_id := 999;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'370',2,p_array,i_arbeitsplatz,i_programm);--laut Zeichnung
      end if;
      
  end if;
  
  
   
  EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.form_profil Abgrenzung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.form_profil APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END form_profil;
  
  
/*
* Ablauf vorplanieren
*
*
*/
  PROCEDURE vorplanieren(
      prod_r produktions_record) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'vorplanieren ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3);
   i_doPlanieren boolean default false;
   
   p_array PKG_UTIL_APL.array_var_text_time;
   
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  
  
  
      i_arbeitsplatz := PKG_UTIL_APL.getPlanierBank_AP(prod_r,i_gruppen_id);
      
      /*
     
     
     --Abgrenzung vorplanieren
        if  prod_r.T_PRESSDURCHMESSER1 <530 and prod_r.T_KORNGROESSE>120 and
            substr(prod_r.T_KORNQUALITAET,1,2) in ('SC','EK') and
            prod_r.T_KA526 <> '8' and 
            prod_r.T_SUPFEIN = '0' then
            i_gruppen_id := 1;
            i_arbeitsplatz := '545';
        elsif  prod_r.T_PRESSDURCHMESSER1 <530 and prod_r.T_KORNGROESSE>180 and
            prod_r.T_KA526 <> '8' and 
            prod_r.T_SUPFEIN = '0' then
            i_gruppen_id := 2;
            i_arbeitsplatz := '545';
         elsif  prod_r.T_PRESSDURCHMESSER1 <530 and  prod_r.T_PRESSBREITE <=15 and
            prod_r.T_KA526 <> '8' and 
            prod_r.T_SUPFEIN = '0' then
            i_gruppen_id := 3;
            i_arbeitsplatz := '545';
        elsif prod_r.T_PRESSDURCHMESSER1 <530 then
            i_gruppen_id := 4;
            i_arbeitsplatz := '546';
        elsif prod_r.T_PRESSDURCHMESSER1 <=410 and prod_r.T_KA526 = '8'  then
            i_gruppen_id := 5;
            i_arbeitsplatz := '546';
        else
            i_gruppen_id := 6;
            i_arbeitsplatz := '547';
        end if;
        */
        --einfuegen vorplanieren
        i_programm := i_programm_name || i_gruppen_id;
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',1,p_array,i_arbeitsplatz,i_programm);
        i_programm := i_programm_name || i_gruppen_id;
            
        --Hinweis 2mm Aufmass
        i_gruppen_id := 7;
        i_programm := i_programm_name || i_gruppen_id;
        p_array(1) := '2';
        p_array(2) := to_char(prod_r.T_NENNBREITE + 2,'99G990D90');
        PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'250',2,p_array,i_arbeitsplatz,i_programm);
      
   

  
   
  EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.vorplanieren APLNR:'||prod_r.T_arbeitsplannummer||' Abgrenzung ->>' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.vorplanieren APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END vorplanieren;

 /*
* Ablauf planieren
*
*
*/
  PROCEDURE planieren(
      prod_r produktions_record) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'planieren ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3);
   i_doPlanieren boolean default false;
   
   p_array PKG_UTIL_APL.array_var_text_time;
   
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  
  
  --feinschleifen
  if prod_r.T_KA524 = '9' or (prod_r.T_BN_MAX_TOL-prod_r.T_BN_MIN_TOL)<=0.2 then -- 4=9 bedeutet Planfläche feinschleifen 
      -- kunde wünscht kein planieren oder feinschleifen 
      -- ACHTUNG Abgrenzung fehlt noch!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      
      if not p_isFeinschleifenAblauf then
          --Sonderablauf Feinschleifen aktivieren
          p_isFeinschleifenAblauf := true;
          
          if ( prod_r.T_PRESSBREITE - prod_r.T_NENNBREITE) >=3 then
              vorplanieren(prod_r);--vorplanieren
          end if;
      else
          if prod_r.T_BINDUNG = ' AV' then
              i_gruppen_id := 24;
              i_programm := i_programm_name || i_gruppen_id;
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'501',i_programm);--feinschleifen
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',5,p_array,'501',i_programm);--feinschleifen Planfläche
              PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
          else
              i_gruppen_id := 25;
              i_programm := i_programm_name || i_gruppen_id;
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'624',i_programm);--feinschleifen
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',5,p_array,'624',i_programm);--feinschleifen Planfläche
              PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
              p_isTrocken := false;
              trocknen(prod_r); --trocknen vorher
          end if;
      end if;
      
      return;
  end if;
  
  -- kein schleifen
  if prod_r.T_KA522 = '8'  then -- kunde wünscht kein planieren  
      return;
  end if;
  
  if prod_r.T_BEZEICHNUNG in ('SLS') then  --Fertigmass nicht planieren
      if (prod_r.T_PRESSDURCHMESSER1< 103 and prod_r.T_PRESSBREITE <= (prod_r.T_NENNBREITE + prod_r.T_BN_MAX_TOL) and prod_r.T_KA529 <> '2') or
         (prod_r.T_PRESSDURCHMESSER1< 103 and prod_r.T_PRESSBREITE <= (prod_r.T_NENNBREITE + 0.5) and prod_r.T_KA529 <> '2') then 
         return;  --nicht planieren
      end if;
      
      --Abgrenzunng planieren ja oder nein
      if  prod_r.T_CHARAKTERISTIKA = 'R' and prod_r.T_PRESSDURCHMESSER1>100 and prod_r.T_PRESSDURCHMESSER1<=810 and
          prod_r.T_KORNGROESSE <= 36 and
          prod_r.t_NENNBREITE<=160 and
          prod_r.T_PRESSBREITE < (prod_r.T_NENNBREITE + prod_r.T_BN_MAX_TOL + 0.5) then
              if prod_r.T_ALUFOLIE_KZ in ('3','I','6','9','C','F') or
                 prod_r.T_AUSSPARUNG1DN1 > 0  or
                 prod_r.T_KA522 in ('1','2')  or
                 prod_r.T_KA521 in ('5')  or
                 prod_r.T_KA524 in ('1','4')  or
                 prod_r.T_KA526 in ('8')  or
                 prod_r.T_KA527 in ('2')  then
                     i_doPlanieren := true;
              end if;
      else
          i_doPlanieren := true;
      end if;
      
      
      --KZ planieren = true, dann Arbeitsplatz bestimmen und ausgeben
      if i_doPlanieren then
          DBMS_OUTPUT.PUT_LINE( 'planieren -->   '|| prod_r.T_BEZEICHNUNG);
          if prod_r.T_NENNDURCHMESSER<=100 then -- Kleinschleifkörper
              if prod_r.T_KA521 = '5  ' then --abgrenzung fehlt noch
                  i_gruppen_id := 100;
                  i_programm := i_programm_name || i_gruppen_id;
                  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'624',i_programm);--schleifen
                  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',7,p_array,'624',i_programm);--zweiseitig
                  PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
                  p_isTrocken := false;
              elsif prod_r.T_KA521 = '5' then
                  i_gruppen_id := 100;
                  i_programm := i_programm_name || i_gruppen_id;
                  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'624',i_programm);--schleifen
                  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',6,p_array,'624',i_programm);--einseitig
                  PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
                  p_isTrocken := false;
                  if not PKG_UTIL_APL.isFormProfil(prod_r) then
                      trocknen(prod_r);
                  end if;
              else
                  i_gruppen_id := 130;
                  i_programm := i_programm_name || i_gruppen_id;
                  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'620',i_programm);--schleifen
                  PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
                  p_isTrocken := false;
              end if;
              return; -- zurück/ende
          else
              i_arbeitsplatz := PKG_UTIL_APL.getPlanierBank_AP(prod_r,i_gruppen_id );
          end if;
      else
          DBMS_OUTPUT.PUT_LINE( 'nicht planieren -->   '|| prod_r.T_BEZEICHNUNG);
          i_gruppen_id := -1;
          return;
      end if;

  end if;
  
   DBMS_OUTPUT.PUT_LINE( 'planieren --> id gruppe:   '|| i_gruppen_id);
   
  --Arbeitsplan ausgabe planieren
  if i_gruppen_id > 0 then
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,i_arbeitsplatz,i_programm);--planieren
      PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
  else
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'255',1,p_array,i_arbeitsplatz,i_programm);--planieren
      PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
      p_array(1) := 'Fehler in Abgrenzung Planieren';
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'ERR',1,p_array,i_arbeitsplatz,i_programm);--planieren
      
      raise ABGRENZUNG_FEHLER;
  end if;
 

  
   
  EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.planieren APLNR:'||prod_r.T_arbeitsplannummer||' Abgrenzung ->>' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.planieren APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END planieren;
  
  
  
  
 /*
* Ablauf feinschleifen
*
*
*/
  PROCEDURE feinschleifen(
      prod_r produktions_record) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'planieren ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3);
   i_doPlanieren boolean default false;
   
   p_array PKG_UTIL_APL.array_var_text_time;
   
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  
  
  --feinschleifen
  if prod_r.T_KA524 = '9' then -- 4=9 bedeutet Planfläche feinschleifen 
      -- kunde wünscht kein planieren oder feinschleifen 
      -- ACHT(UNg Abgrezung fehlt noch!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      i_gruppen_id := 15;
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',1,p_array,'624',i_programm);--feinschleifen
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'265',5,p_array,'624',i_programm);--feinschleifen Planfläche
      PKG_UTIL_APL.setToleranz('BN',v_aplsatz_obj,prod_r,i_programm);
      p_isTrocken := false;
      trocknen(prod_r); --trocknen vorher
      return;
  end if;
  

  
   
  EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.feinschleifen APLNR:'||prod_r.T_arbeitsplannummer||' Abgrenzung ->>' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.feinschleifen APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END feinschleifen;  
  
  
  /*
* Ablauf bohren und aussparen
*
*
*/
  PROCEDURE bohren(
      prod_r produktions_record) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'bohren ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3);
   i_doPlanieren boolean default false;
   
   p_array PKG_UTIL_APL.array_var_text_time;
   i_isBohren boolean default true;
   
  BEGIN
  
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  i_gruppen_id := 0; 
   -- nicht bohren!
   
   
  if prod_r.T_NENNBOHRUNG = 0 or prod_r.T_KA529 = '1' or prod_r.T_KA524 = '6'  
     or prod_r.T_KA523 in ('3','6') or  prod_r.T_KA5212 in( '2','5') or 
    (prod_r.T_PRESSBOHRUNG >= (prod_r.T_NENNBOHRUNG + prod_r.T_BON_MAX_TOL) and  prod_r.T_KA5211 not in( '2','5')) then 
         i_isBohren := false;  --nicht bohren  
   
         -- eventuell nacharbeiten?
 else
        i_isBohren := true;
         -- bohren 
        if prod_r.T_PRESSDURCHMESSER1 >= 615.7 then  
            if (prod_r.T_NENNBOHRUNG - prod_r.T_PRESSBOHRUNG)  >0.3 or
                prod_r.T_PRESSBOHRUNG > 100 then
                if prod_r.T_PRESSDURCHMESSER1 > 811 or 
                   (prod_r.T_PRESSDURCHMESSER1 <= 811 and prod_r.T_PRESSDURCHMESSER1 > 707 and prod_r.T_NENNBREITE > 80) or
                   (prod_r.T_PRESSDURCHMESSER1 > 664 and prod_r.T_PRESSDURCHMESSER1 <= 707 and prod_r.T_NENNBREITE > 100 and prod_r.T_NENNBREITE <= 150) then 
                    i_gruppen_id   := 100;
                    i_arbeitsplatz := 536;
                elsif  (prod_r.T_PRESSDURCHMESSER1 <= 811 and  prod_r.T_NENNBREITE <= 80) or 
                   (prod_r.T_PRESSDURCHMESSER1 <= 707 and prod_r.T_NENNBREITE <= 100) or
                   (prod_r.T_PRESSDURCHMESSER1 <= 664 and prod_r.T_NENNBREITE <= 120) then 
                    i_gruppen_id   := 110;
                    i_arbeitsplatz := 535;
                elsif  prod_r.T_PRESSDURCHMESSER1 <= 664 and  prod_r.T_NENNBREITE > 120 and  
                    prod_r.T_NENNBREITE <= 320 then 
                    i_gruppen_id   := 110;
                    i_arbeitsplatz := 502;
                else
                  raise ABGRENZUNG_FEHLER;
                end if;
            else
                DBMS_OUTPUT.PUT_LINE( 'Bohren --> BOn-BOP <=0.3'|| SQLERRM);
                i_gruppen_id :=  -120;
                return;
            end if;
        elsif prod_r.T_PRESSDURCHMESSER1 >= 410.5 then  
            if (prod_r.t_NENNBOHRUNG - prod_r.T_PRESSBOHRUNG)  >0.2 then
                if prod_r.T_KA522 in ('1','2') or prod_r.T_KA524 = '1' or prod_r.T_KA524='2' and prod_r.T_NENNBREITE<130  then 
                    i_gruppen_id   := 200;
                    i_arbeitsplatz := 535;
                elsif  prod_r.T_KA524 <> '3' and (prod_r.T_NENNBREITE - prod_r.T_AUSSPARUNG1TIEFE - prod_r.T_AUSSPARUNG2TIEFE) <= 110 and
                       prod_r.T_NENNBREITE<=125 then
                    i_gruppen_id   := 210;
                    i_arbeitsplatz := 535;
                elsif  prod_r.T_KA524 <> '3' and (prod_r.T_NENNBREITE - prod_r.T_AUSSPARUNG1TIEFE - prod_r.T_AUSSPARUNG2TIEFE) <= 320 and
                       prod_r.T_PRESSBOHRUNG  >= 60 then
                    i_gruppen_id   := 220;
                    i_arbeitsplatz := 502;
                elsif  prod_r.T_KA524 <> '3' and (prod_r.T_NENNBREITE - prod_r.T_AUSSPARUNG1TIEFE - prod_r.T_AUSSPARUNG2TIEFE) <= 320 and
                       prod_r.T_PRESSBOHRUNG  >= 60 then
                    i_gruppen_id   := 230;
                    i_arbeitsplatz := 502;
                elsif  prod_r.T_KA524 <> '3' and prod_r.T_PRESSBOHRUNG  >= 20 and prod_r.T_PRESSBOHRUNG  <= 60 then
                    i_gruppen_id   := 240;
                    i_arbeitsplatz := 535;
                else
                  raise ABGRENZUNG_FEHLER;
                end if;
            else
                DBMS_OUTPUT.PUT_LINE( 'Bohren --> BOn-BOP <=0.2');
                i_gruppen_id :=  -130;
                return; --differenz zu BOP BON zu klein
            end if;
        
        elsif prod_r.T_PRESSDURCHMESSER1 >= 300 then  
            if (prod_r.t_NENNBOHRUNG - prod_r.T_PRESSBOHRUNG)  >0.1 or  
               ((prod_r.t_NENNBOHRUNG - prod_r.T_PRESSBOHRUNG) > -0.4  and  
               (prod_r.T_NENNBREITE - prod_r.T_AUSSPARUNG1TIEFE - prod_r.T_AUSSPARUNG2TIEFE) >= 30 and
                prod_r.T_NENNBOHRUNG> 58)then
                if (prod_r.T_HAERTE < 'I' and (prod_r.T_NENNDURCHMESSER-prod_r.T_AUSSPARUNG1DN1) <= 30 and prod_r.T_AUSSPARUNG1DN1=0) or
                   ((prod_r.T_NENNDURCHMESSER-prod_r.T_AUSSPARUNG1DN1) <= 20 and prod_r.T_AUSSPARUNG1DN1=0)  then 
                    i_gruppen_id   := 300;
                    i_arbeitsplatz := '505';
                elsif  prod_r.T_NENNBREITE <  100 then
                    i_gruppen_id   := 310;
                    i_arbeitsplatz := 503;
                else
                    i_gruppen_id   := 320;
                    i_arbeitsplatz := 502;
                end if;
            else
                DBMS_OUTPUT.PUT_LINE( 'Bohren --> BON-BOP <=0.1');
                i_gruppen_id :=  -140;
                --return; --differenz zu BOP BON zu klein
            end if;
        
        
         else
          
            if (prod_r.t_NENNBOHRUNG - prod_r.T_PRESSBOHRUNG)  >0.05 then
                if (prod_r.T_KA521 = '5' and prod_r.T_NENNDURCHMESSER < 65) then 
                    i_gruppen_id   := 400;
                    i_arbeitsplatz := '505';
                elsif   (prod_r.T_KA521 = '5' and prod_r.T_NENNDURCHMESSER <= 265) then 
                    i_gruppen_id   := 410;
                    i_arbeitsplatz := '570';
                elsif prod_r.T_KA521 = '5' then
                    i_gruppen_id   := 420;
                    i_arbeitsplatz := '503';
                elsif (prod_r.T_NENNDURCHMESSER < 100 and prod_r.T_NENNBREITE < 2) or 
                      prod_r.T_NENNBREITE < 1.5 then
                    i_gruppen_id   := 430;
                    i_arbeitsplatz := '505';
                elsif (prod_r.T_NENNDURCHMESSER < 150 and prod_r.T_NENNBOHRUNG < 20) then
                    i_gruppen_id   := 440;
                    i_arbeitsplatz := '505';
                else
                    i_gruppen_id   := 450;
                    i_arbeitsplatz := '570';
                end if;
            else
                DBMS_OUTPUT.PUT_LINE( 'Bohren --> BOn-BOP <=0.05');
                i_gruppen_id :=  -150;
                --return; --differenz zu BOP BON zu klein
            end if;
            
        end if;  
   end if; --fürs bohren    
   
   
  
  if i_gruppen_id > 0 then
      
      --Bohren und aussparen
      if prod_r.T_AUSSPARUNG1DN1 is not null and  prod_r.T_AUSSPARUNG1DN1 > 0 then
          i_programm := i_programm_name || i_gruppen_id;
          i_bohren_ap := i_arbeitsplatz;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'316',1,p_array,i_arbeitsplatz,i_programm);--bohren
          if prod_r.T_AUSSPARUNG2DN1 is not null and  prod_r.T_AUSSPARUNG2DN1 > 0 then
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'316',2,p_array,i_arbeitsplatz,i_programm);--1. Seite
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'316',3,p_array,i_arbeitsplatz,i_programm);--2. Seite
          end if;
      
          PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm,6);
          PKG_UTIL_APL.setToleranz('AUSSPAR',v_aplsatz_obj,prod_r,i_programm,6);
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
          
      -- nur bohren
      else
          i_programm := i_programm_name || i_gruppen_id;
          i_bohren_ap := i_arbeitsplatz;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'330',1,p_array,i_arbeitsplatz,i_programm);--bohren
          PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);
      end if;
  else --nacharbeiten und nur aussparung
      /*if i_isBohren then*/
      
          bohrung_nacharbeiten(prod_r);
          --DBMS_OUTPUT.PUT_LINE( 'Bohren -->is' || SQLERRM);
      if prod_r.T_KA523 = '6' then --Bohrung kitten
          --DBMS_OUTPUT.PUT_LINE( 'Bohren kitten-->' || SQLERRM);
          i_gruppen_id   := 500;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'325',1,p_array,'592',i_programm);--bohren
          PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);
      end if;
      if (prod_r.T_AUSSPARUNG1DN1 is not null and  prod_r.T_AUSSPARUNG1DN1 > 0) or prod_r.T_KA5211 = '4' then
          if  prod_r.T_KA5212 = '4' then
              return;  --kein aussparen
          end if;
          if i_arbeitsplatz is null or i_arbeitsplatz = '   ' then
              i_arbeitsplatz := PKG_UTIL_APL.getBohrbank_AP(prod_r,i_gruppen_id);
              i_gruppen_id := i_gruppen_id||600;
          end if;
          
          i_programm := i_programm_name || i_gruppen_id;
          i_bohren_ap := i_arbeitsplatz;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'365',1,p_array,i_arbeitsplatz,i_programm);--aussparen
          PKG_UTIL_APL.setToleranz('AUSSPAR',v_aplsatz_obj,prod_r,i_programm,6);
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',300,p_array,i_arbeitsplatz,i_programm);-- Abmessung
      end if;
  end if;
 

  
   
  EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.bohren Abgrenzung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.bohren APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END bohren;
  
  
  /*
* Ablauf bohrung_nacharbeiten
*
*
*/
  PROCEDURE bohrung_nacharbeiten(
      prod_r produktions_record) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'bohren ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3);
   i_doPlanieren boolean default false;
   
   p_array PKG_UTIL_APL.array_var_text_time;
   
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  i_gruppen_id := 10; 
 
  
  if (prod_r.T_PRESSBOHRUNG - prod_r.T_NENNBOHRUNG) <= 0.3 and
      prod_r.T_NENNBOHRUNG <=58 and  prod_r.T_NENNBOHRUNG > 0 and
      (prod_r.T_NENNBREITE - prod_r.T_AUSSPARUNG1TIEFE - prod_r.T_AUSSPARUNG2TIEFE) between 25 and 42 and
      prod_r.T_KA527 <> '7' and prod_r.T_KA523 not in ( '6', '8', '9','4') then
          i_programm := i_programm_name || i_gruppen_id;
          i_bohren_ap := i_arbeitsplatz;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'331',1,p_array,'658',i_programm);--bohrung nacharbeiten
          PKG_UTIL_APL.setToleranz('BON',v_aplsatz_obj,prod_r,i_programm);
  end if;
 

  
   
  EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.bohrung_nacharbeiten Abgrenzung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.bohrung_nacharbeitenAPLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END bohrung_nacharbeiten;
  
  
 /*
* Ablauf stirnen
*
*
*/
  PROCEDURE stirnen(
      prod_r produktions_record) AS
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'stirnen ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3);
   i_doPlanieren boolean default false;
   
   p_array PKG_UTIL_APL.array_var_text_time;
   
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
   
 

 if prod_r.T_BEZEICHNUNG in ('SLS') then  --Fertigmass nicht stirnen
     /* wachsen oder schrufen die SLS? , daher immer andrucken!!! bevor nicht geklärt ist ob
      die Scheibe im Maß ist.
     */
    
      /*if prod_r.T_PRESSDURCHMESSER1 <= (prod_r.T_NENNDURCHMESSER + prod_r.T_DN_MAX_TOL) and  prod_r.T_KA5211 <> '3'   then 
         return;  --nicht stirnen
      end if;*/
     
     if  prod_r.T_KA5212 in ( '3','5') then 
         return;  --nicht stirnen
      end if;
     
     
    if prod_r.T_PRESSBOHRUNG = 0 and prod_r.T_BEZEICHNUNG in ('SLS') then
        if  prod_r.T_NENNBREITE> 50 and prod_r.T_NENNDURCHMESSER <= 65 then 
              i_gruppen_id := 100;
              i_arbeitsplatz :=655;
        else
            raise ABGRENZUNG_FEHLER;
        end if;
    elsif prod_r.T_PRESSDURCHMESSER1 >= 615.7 then
        if  prod_r.T_PRESSDURCHMESSER1<665  and prod_r.T_NENNBREITE <= 350 and prod_r.T_NENNBOHRUNG>=20 and prod_r.T_KORNGROESSE > 36 then 
              i_gruppen_id := 200;
              i_arbeitsplatz :=540;
        elsif  prod_r.T_PRESSDURCHMESSER1<665  and prod_r.T_NENNBREITE >= 150 and prod_r.T_NENNBREITE <= 350 and 
              prod_r.T_NENNBOHRUNG>=20 and prod_r.T_KORNGROESSE <= 36 then 
              i_gruppen_id := 210;
              i_arbeitsplatz :=540;
        elsif  prod_r.T_NENNBREITE <= 120  then 
              i_gruppen_id := 220;
              i_arbeitsplatz :=536;
        else
              i_gruppen_id := 230;
              i_arbeitsplatz :=526;
        end if;
    elsif prod_r.T_PRESSDURCHMESSER1 >= 410.5 then
        if  prod_r.T_NENNBOHRUNG>=20 and prod_r.T_KORNGROESSE > 36 then 
              i_gruppen_id := 300;
              i_arbeitsplatz :=540;
        else
              i_gruppen_id := 310;
              i_arbeitsplatz :=518;
        end if;
    elsif prod_r.T_PRESSDURCHMESSER1 >= 300 then
        i_gruppen_id := 400;
        i_arbeitsplatz :=540;
    elsif prod_r.T_PRESSDURCHMESSER1 >= 65 then
        if  prod_r.T_NENNBREITE <= 90  then 
              i_gruppen_id := 500;
              i_arbeitsplatz := 560;
        else
              i_gruppen_id := 510;
              i_arbeitsplatz := 521;
        end if;
    else
        if  prod_r.T_NENNBOHRUNG <=10 and prod_r.T_AUSSPARUNG1DN1 = 0  then 
              i_gruppen_id := 600;
              i_arbeitsplatz :=651;
        elsif  prod_r.T_BEZEICHNUNG in ('HHS','HSG') and prod_r.T_AUSSPARUNG1DN1 = 0  then 
              i_gruppen_id := 610;
              i_arbeitsplatz :=638;
        elsif  prod_r.T_STUECK_WERK2 > 100 and prod_r.T_HAERTE <= 'L'  then 
              i_gruppen_id := 620;
              i_arbeitsplatz :=631;
        else
              i_gruppen_id := 630;
              i_arbeitsplatz := 630;
        end if;
    end if;    
  end if;
  
  
  if i_gruppen_id > 0 then
      i_programm := i_programm_name || i_gruppen_id;
      
     
     -- Ausgabe Arbeitsgang
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',1,p_array,i_arbeitsplatz,i_programm);--
      
      --Paket oder Einzelspannung
      if i_arbeitsplatz = '560' and  PKG_UTIL_APL.ap560_is_paketspannung(prod_r) then
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',4,p_array,i_arbeitsplatz,i_programm);--
      elsif i_arbeitsplatz = '560' then
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'355',3,p_array,i_arbeitsplatz,i_programm);--
       end if;
       -- Abmessung
      PKG_UTIL_APL.setToleranz('DN',v_aplsatz_obj,prod_r,i_programm);
      
     
  end if;
 

  
   
  EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.stirnen Abgrenzung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.stirnen APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END stirnen;
  
  

  
  /*
* Ablauf revision
*
*
*/
  PROCEDURE revision(
      prod_r produktions_record,
      find OUT BOOLEAN) AS
      
      
   i_gruppen_id number default 0;
   i_programm_name varchar2(32) default 'revision ';
   i_programm varchar2(32);
   i_arbeitsplatz varchar2(3); 
   b_ausnahme1 boolean default false;
   p_array PKG_UTIL_APL.array_var_text_time;
   
   
  i_revision PKG_UTIL_APL.array_var_revision;
   
  BEGIN
  p_array := PKG_UTIL_APL.array_var_text_time(0,0,0,0,0);
  b_ausnahme1 := false; 

  i_revision := PKG_UTIL_APL.getRevision_AP(prod_r);
   
  -- vorher immer abblasen bevor es in die Revision geht, ausser bei RLS, oder  wachs
  if prod_r.T_BEZEICHNUNG <> 'RLS' and  prod_r.T_KA5214 <> 'W'  and  p_isRevision_abblasen then
      i_gruppen_id := 0;
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'385',1,p_array,'591',i_programm);--Abblasen
  end if;
  
  --
  --Bohrung ausstreichen?
  austreichen_bohrung(prod_r);
  
  
  -- Eingang Revision 
  i_gruppen_id := 10;
  i_programm := i_programm_name || i_gruppen_id;
  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'537',1,p_array,'821',i_programm);--Eingang Revision
  
  if prod_r.T_KA5213 is null or prod_r.T_KA5213 not in ('1','2','3') then -- Honringe nicht hier mass und sichtkontrolle
      i_gruppen_id := 100;
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'562',1,p_array,i_revision(1),i_programm);--Sichtkontrolle
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'561',1,p_array,i_revision(1),i_programm);--Masskontrolle
  
      if prod_r.T_NENNDURCHMESSER>80 then -- nicht Kleinschleifkörper
          if prod_r.t_BEZEICHNUNG='SLS' then
              i_gruppen_id := 110;
              i_programm := i_programm_name || i_gruppen_id;
              --PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'543',1,p_array,i_revision(1),i_programm);--Stückzahl und Planparallelität
              p_array(1) :=   to_char(prod_r.T_PLAN_TOL,'0D0');--to_char(PKG_UTIL_APL.getPlanlauftoleranz(prod_r),'0D0');
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'543',2,p_array,i_revision(1),i_programm);--Stückzahl und Planparallelität
          end if;
          if PKG_UTIL_APL.isFormProfil(prod_r) then
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'539',1,p_array,i_revision(1),i_programm);--Form und Profil Kontrolle
          end if;
      end if;
  end if;
  
  --Ausnahme Kleinschleifkörper, RLS, KA5210=2, kein normaler Ablauf Revision
  if prod_r.T_BEZEICHNUNG = 'RLS' or prod_r.T_KA5210='2' or  prod_r.T_NENNDURCHMESSER<=80 then
      b_ausnahme1 := true;
       null;
  elsif prod_r.T_KA522  in ('1','2') then
       i_gruppen_id := 140;
       i_programm := i_programm_name || i_gruppen_id;
       PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'545',1,p_array,i_revision(1),i_programm);--Gewindekontrolle
  else
      if  prod_r.T_NENNDURCHMESSER > 300 then
          i_gruppen_id := 110;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',1,p_array,i_revision(2),i_programm);--auswuchten
      else
          i_gruppen_id := 115;
          i_programm := i_programm_name || i_gruppen_id;
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',1,p_array,i_revision(2),i_programm);--auswuchten rollbock
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',7,p_array,i_revision(2),i_programm);-- rollbock
      end if;
          
      if prod_r.T_UMWUCHT_SOLL is not null and prod_r.T_UMWUCHT_SOLL <> '   ' then
          i_gruppen_id := 120;
          i_programm := i_programm_name || i_gruppen_id;
          p_array(1) :=  prod_r.T_UMWUCHT_SOLL;  --Kundenwunsch Vorgabe
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',4,p_array,i_revision(2),i_programm); --Kunden unwucht gewicht
      elsif prod_r.T_KORNGROESSE = 600 and prod_r.T_KORNQUALITAET='SC4' then
          i_gruppen_id := 125;
          i_programm := i_programm_name || i_gruppen_id;
          p_array(1) :=  round(prod_r.T_NETTOGEWICHT_KG*1000);
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',5,p_array,i_revision(2),i_programm); --Sonder unwucht gewicht
      else
          i_gruppen_id := 130;
          i_programm := i_programm_name || i_gruppen_id;
          p_array(1) := PKG_UTIL_APL.getAuswuchtGewicht(prod_r);
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',3,p_array,i_revision(2),i_programm); --unwucht gewicht
      end if;
          
      if prod_r.T_KORNGROESSE< 120 and prod_r.T_CHARAKTERISTIKA<> 'R' then
              i_gruppen_id := 135;
              i_programm := i_programm_name || i_gruppen_id;
              PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'541',6,p_array,i_revision(2),i_programm); --schlämmen
      end if;
  end if;
     
  if prod_r.T_KA523 in ('2','8','9') and not b_ausnahme1 then
      i_gruppen_id := 140;
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'551',1,p_array,i_revision(1),i_programm); --Reduring einsetzen    
  end if;
      
  if b_ausnahme1 then
      null;
      -- ***********Test  kleine Tourenprüfmaschine*****************************************************************
     -- i_gruppen_id := 150.1;
     --  i_programm := i_programm_name || i_gruppen_id;
     --  p_array(1) := PKG_UTIL_APL.getPruefGeschwindigkeit(prod_r);
      -- PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'540',1,p_array,'709',i_programm); --tourenprüfung 
      --PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',10001,p_array,'709',i_programm); --Probe Geschwindigkeit! 
      --****************************************************************************************************************
  elsif  prod_r.T_METER_JE_SEC >=40  or (prod_r.T_METER_JE_SEC >=32 and (prod_R.T_STRUKTUR >= '07' or prod_R.T_ANFEUCHTUNG='GI')) then
      i_gruppen_id := 150;
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'540',1,p_array,i_revision(3),i_programm); --tourenprüfung    
      p_array(1) := PKG_UTIL_APL.getPruefGeschwindigkeit(prod_r);
      if p_array(1)> to_number(i_revision(4)) then
          p_array(2) := i_revision(4);
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'HHH',10001,p_array,i_revision(3),i_programm); --Probe Geschwindigkeit! 
      end if;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'540',2,p_array,i_revision(3),i_programm); --Probe Geschwindigkeit! 
      if i_revision(3) = '709' and i_revision(4) = '5000' and prod_r.T_NENNDURCHMESSER > 80 then --zusatzinfo bei AP=709
          p_array(1) := PKG_UTIL_APL.getDrehzahleinstellung(PKG_UTIL_APL.getPruefGeschwindigkeit(prod_r));
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'540',3,p_array,i_revision(3),i_programm); --Drehzahleinstellung! 
          p_array(1) :=  round(p_array(1) * 1.5,1);
          PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'540',4,p_array,i_revision(3),i_programm); --Drehzahleinstellung! 
      end if;
      
  else
      i_gruppen_id := 155;
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'544',1,p_array,i_revision(1),i_programm); --Klankprüfung
  end if;
      
  --signieren/flanschen 
  signieren_flanschen(prod_r,i_revision(1));

  --Abgrenzung Vorpacken
  if (prod_r.T_NENNDURCHMESSER <= 250 or prod_r.T_NENNBREITE<=10 or  prod_r.T_METER_JE_SEC >=125) and i_revision(5) != '   ' then
      i_gruppen_id := 155;
      i_programm := i_programm_name || i_gruppen_id;
      PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'584',1,p_array,i_revision(5),i_programm); --Vorpacken  
  end if;
      
  -- Eingang Packraum 
  i_gruppen_id := 200;
  PKG_UTIL_APL.setAPlanSatz(prod_r,v_aplsatz_obj,'595',1,p_array,'750',i_programm);
  
  find := true;
  
  
   
  EXCEPTION
    WHEN ABGRENZUNG_FEHLER THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.revision Abgrenzung APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE( 'ERROR -->' || SQLERRM);
      sqlerror :='ERROR -->PKG_WERK2.revision APLNR:'||prod_r.T_arbeitsplannummer||' Error:' || SQLERRM;
      INSERT INTO LOGTAB
        (TEXT
        ) VALUES
        (sqlerror
        );
  END revision;




END PKG_WERK2;
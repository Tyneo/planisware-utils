/*
  ATTENTION, IL FAUT CREER UNE DIRECTORY ORACLE POUR DESIGNER LE REPERTOIRE DE DESTINATION
  > CREATE OR REPLACE DIRECTORY EXPORT_PLW AS 'E:\Planisware\Data'
  Exemple de script d'appel pour l'export d'une table ou vue AAAAAAA dans AAAAAAA.csv,
  EXPORT_PLW étant l'objet Oracle de type DIRECTORY :
  > call BT_Extraction_Table ('AAAAAAA','EXPORT_PLW','AAAAAAA.csv');
*/

CREATE OR REPLACE PROCEDURE export_table_to_csv
  (
    PC$Table      in Varchar2,                      -- Nom de la table a extraire
    PC$Dir        in Varchar2,                      -- Directory de destination
    PC$Fichier    in Varchar2,                      -- Nom du fichier de sortie
    PC$Separateur in Varchar2 Default ';',          -- Caractere de separation
    PC$Entetes    in Varchar2 Default 'O',          -- Affichage de l'entete des colonnes
    PC$DateFMT    in Varchar2 Default 'DD/MM/YYYY', -- Format des dates
    PC$Where      in Varchar2 Default Null,         -- Clause Where de filtrage
    PC$Order      in Varchar2 Default Null,          -- Colonne de tri
    PC$EspaceEntetes in Varchar2 Default 'O'         -- Si 'O', remplace le caractere _ par un espace dans l'entête
  ) IS
  
LF$Fichier  UTL_FILE.FILE_TYPE ;
LC$Ligne    Varchar2(32767) ;
LI$I        Integer ;
LC$DateFMT  Varchar2(40) := '''' || PC$DateFMT || '''' ;


TYPE REFCUR1 IS REF CURSOR ;
cur    REFCUR1;


-- Colonnes de la table --
  CURSOR C_COLTAB ( PC$Tab IN VARCHAR2 ) IS
  SELECT
    COLUMN_NAME,
  DATA_TYPE
  FROM
    USER_TAB_COLUMNS
  WHERE
    TABLE_NAME = PC$Tab
  AND
    DATA_TYPE IN ('CHAR','VARCHAR2','NUMBER','DATE','FLOAT')
   order by COLUMN_ID
  ;

LC$Separateur  Varchar2(2) := PC$Separateur ;
LC$Requete  Varchar2(10000) ;
LC$Desc    Varchar2(10000) ;
LC$SQLW    VARCHAR2(10000):= 'SELECT ';
LC$Col    VARCHAR2(256);
Select_count integer;


-----------------------------------------
-- Ouverture d'un fichier d'extraction --
-----------------------------------------
FUNCTION Ouvrir_fichier
  (
    PC$Dir in Varchar2,
    PC$Nom_Fichier in Varchar2
  ) RETURN UTL_FILE.FILE_TYPE
IS
  Fichier  UTL_FILE.FILE_TYPE ;
  LC$Msg  Varchar2(256);

Begin

  Fichier := UTL_FILE.FOPEN( PC$Dir, PC$Nom_Fichier, 'w', 32764 ) ;
  --Fichier := UTL_FILE.FOPEN( 'ctemp', PC$Nom_Fichier, 'W', 32764 ) ;
  --Fichier := UTL_FILE.FOPEN( 'C:\TEMP\', 'test.txt', 'w', 32764 ) ;

  If not UTL_FILE.IS_OPEN( Fichier ) Then
  LC$Msg := 'Erreur ouverture du fichier (' || PC$Dir || ') ' || PC$Nom_Fichier ;
    RAISE_APPLICATION_ERROR( -20100, LC$Msg ) ;
  End if ;

  Return( Fichier ) ;

Exception

When UTL_FILE.INVALID_PATH Then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'File location is invalid.';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
When UTL_FILE.INVALID_MODE Then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'The open_mode parameter in FOPEN is invalid.';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
When UTL_FILE.INVALID_FILEHANDLE Then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'File handle is invalid.';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
When UTL_FILE.INVALID_OPERATION  Then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'File could not be opened or operated on as requested.';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
When UTL_FILE.READ_ERROR  Then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'Operating system error occurred during the read operation.';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
When UTL_FILE.WRITE_ERROR Then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'Operating system error occurred during the write operation.';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
When UTL_FILE.INTERNAL_ERROR then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'Unspecified PL/SQL error';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
---------------------------------------------------------------
-- Les exceptions suivantes sont spécifiques à la version 9i --
-- A mettre en commentaire pour une version antérieure       --
---------------------------------------------------------------
When UTL_FILE.CHARSETMISMATCH Then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'A file is opened using FOPEN_NCHAR,'
    || ' but later I/O operations use nonchar functions such as PUTF or GET_LINE.';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
When UTL_FILE.FILE_OPEN Then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'The requested operation failed because the file is open.';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
When UTL_FILE.INVALID_MAXLINESIZE Then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'The MAX_LINESIZE value for FOPEN() is invalid;'
    || ' it should be within the range 1 to 32767.';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
When UTL_FILE.INVALID_FILENAME Then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'The filename parameter is invalid.';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
When UTL_FILE.ACCESS_DENIED Then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'Permission to access to the file location is denied.';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
When UTL_FILE.INVALID_OFFSET Then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'The ABSOLUTE_OFFSET parameter for FSEEK() is invalid;'
    ||' it should be greater than 0 and less than the total number of bytes in the file.';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
When UTL_FILE.DELETE_FAILED Then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'The requested file delete operation failed.';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
When UTL_FILE.RENAME_FAILED Then
  LC$Msg := PC$Dir || PC$Nom_Fichier || ' : ' || 'The requested file rename operation failed.';
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;
-----------------------------------------------------------------
-- Les exceptions précédentes sont spécifiques à la version 9i --
--     mettre en commentaire pour une version antérieure       --
-----------------------------------------------------------------
When others Then
  LC$Msg := 'Erreur : ' || To_char( SQLCODE ) || ' sur ouverture du fichier ('
     || PC$Dir || ') ' || PC$Nom_Fichier ;
  RAISE_APPLICATION_ERROR( -20070, LC$Msg ) ;

End Ouvrir_fichier ;

Begin
-- ========================== DEBUT DU TRAITEMENT =====================================

-- ========================== CONSTRUCTION DE LA REQUETE ==============================

  LI$I := 1 ;

  FOR COLS IN C_COLTAB( PC$Table ) LOOP
    IF LI$I > 1 THEN
       LC$SQLW := LC$SQLW || '||' ;
    END IF ;

    If COLS.DATA_TYPE IN ('NUMBER','FLOAT') Then
      --LC$Col := 'Decode(' || COLS.COLUMN_NAME || ',NULL, ''NULL'',To_char("'
      --   || COLS.COLUMN_NAME || '"))' ;
      --LC$Col := REPLACE('Decode(' || COLS.COLUMN_NAME || ',NULL, ''NULL'',To_char("'
      --   || COLS.COLUMN_NAME || '"))', '1', '8');
      LC$Col := 'REPLACE(' || COLS.COLUMN_NAME || ', ''.'', '','')';
    ElsIf COLS.DATA_TYPE = 'DATE' Then
       If Upper(PC$Entetes) = 'I' Then
           LC$Col := 'Decode(' || COLS.COLUMN_NAME || ',NULL,''NULL'',''to_date(''''''||'
              || 'To_char("' || COLS.COLUMN_NAME || '",'|| LC$DateFMT ||')' || '||'''''','''|| LC$DateFMT||''')'')' ;
       Else
         LC$Col := 'To_char("'|| COLS.COLUMN_NAME || '",'|| LC$DateFMT ||')' ;
       End if ;
    Else
       If Upper(PC$Entetes) = 'I' Then
        LC$Col := 'Decode(' || COLS.COLUMN_NAME || ',NULL, ''NULL'',' || ''''''''''
         || '|| REPLACE("'|| COLS.COLUMN_NAME || '",CHR(39),CHR(39)||CHR(39))' || '||' || ''''''''')' ;
       Else
        LC$Col := '"'|| COLS.COLUMN_NAME || '"' ;
       End if ;
    End if ;

    IF LI$I = 1 THEN
       LC$SQLW := LC$SQLW || LC$Col ;
    ELSE
       LC$SQLW := LC$SQLW || '''' || LC$Separateur || '''' || '||' || LC$Col  ;
    END IF ;
    LI$I := LI$I + 1 ;
  END LOOP ;

  LC$Requete := LC$SQLW || ' FROM ' || PC$Table ;

  If PC$Where is not null Then
    -- ajout de la clause WHERE --
    LC$Requete := LC$Requete || ' WHERE ' || PC$Where ;
  End if ;
  If PC$Order is not null Then
    -- ajout de la clause ORDER BY --
    LC$Requete := LC$Requete || ' ORDER BY ' || PC$Order ;
  End if ;

   Select_count :=0;
   EXECUTE IMMEDIATE 'SELECT count(*) FROM ('||LC$Requete||')' INTO Select_count;

   if Select_count > 0 then

-- ========================== CREATION FICHIER AVEC ENTETES ==============================


     -- Ouverture du fichier --
    LF$Fichier := Ouvrir_fichier( PC$Dir, PC$Fichier ) ;

    -- Affichage des entetes de colonne ? --
    If Upper(PC$Entetes) = 'O' Then
    LI$I := 1 ;
    For COLS IN C_COLTAB( PC$Table ) Loop
       If PC$EspaceEntetes = 'O' then
         If LI$I = 1 Then
            LC$Ligne := LC$Ligne || replace(COLS.COLUMN_NAME,'_',' ') ;
         Else
            LC$Ligne := LC$Ligne || LC$Separateur ||replace(COLS.COLUMN_NAME,'_',' ') ;
         End if ;
        else
         If LI$I = 1 Then
            LC$Ligne := LC$Ligne || COLS.COLUMN_NAME;
         Else
            LC$Ligne := LC$Ligne || LC$Separateur ||COLS.COLUMN_NAME ;
         End if ;
        end if;

       LI$I := LI$I + 1 ;
    End loop ;
    -- Ecriture ligne entetes --
    UTL_FILE.PUT_LINE( LF$Fichier, LC$Ligne ) ;

    ElsIf Upper(PC$Entetes) = 'I' Then
      LC$Separateur := ',' ;
      LC$Desc := 'INSERT INTO ' || PC$Table || ' (' ;
      LI$I := 1 ;
      For COLS IN C_COLTAB( PC$Table ) Loop
        If LI$I = 1 Then
         LC$Desc := LC$Desc || COLS.COLUMN_NAME;
        Else
         LC$Desc := LC$Desc || LC$Separateur || COLS.COLUMN_NAME ;
        End if ;
        LI$I := LI$I + 1 ;
      End loop ;
      LC$Desc := LC$Desc || ' ) VALUES (' ;
    End if ;

-- ========================== ECRIT DONNEES DANS FICHIER  ===============================

  --  F_TRACE( LC$Requete, 'T' ) ;
    -- Extraction des lignes --
    Open cur For LC$Requete ;
    Loop
    Fetch cur Into LC$Ligne ;
    Exit when cur%NOTFOUND ;
    -- Ecriture du fichier de sortie --
    If Upper(PC$Entetes) = 'I' Then
      UTL_FILE.PUT_LINE( LF$Fichier, LC$Desc || LC$Ligne || ' );' ) ;
    Else
      UTL_FILE.PUT_LINE( LF$Fichier, LC$Ligne ) ;
    End if ;
    End loop ;

    Close cur ;

    -- Fermeture fichier --
    UTL_FILE.FCLOSE( LF$Fichier ) ;
    End if;

End ;

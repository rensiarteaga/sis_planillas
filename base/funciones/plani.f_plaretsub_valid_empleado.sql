DECLARE
  v_registros			record;
  v_planilla			record;
  v_id_funcionario_planilla	integer;
  v_columnas			record;
  v_resp	            varchar;
  v_nombre_funcion      text;
  v_mensaje_error       text;
  v_filtro_uo			varchar;
  v_existe				varchar;
  v_fecha_ini		date;
  v_cantidad_horas_mes	integer;
  v_resultado			numeric;
  v_tiene_incremento	integer;
  v_id_escala			integer;
  v_subsidio_actual		numeric;
BEGIN
	
    v_nombre_funcion = 'plani.f_plaretsub_valid_empleado';
   
	v_existe = 'no';
	select id_tipo_planilla, p.id_gestion, ges.gestion,id_uo, p.id_usuario_reg,p.fecha_planilla
    into v_planilla 
    from plani.tplanilla p
    inner join param.tgestion ges
    	on p.id_gestion = ges.id_gestion
    where p.id_planilla = p_id_planilla;    
    
    v_cantidad_horas_mes = plani.f_get_valor_parametro_valor('HORLAB', v_fecha_ini)::integer;
    v_subsidio_actual = plani.f_get_valor_parametro_valor('MONTOSUB',v_planilla.fecha_planilla);    
    for v_registros in execute('
          select distinct on (uofun.id_funcionario) uofun.id_funcionario , uofun.id_uo_funcionario,fp.id_lugar,uofun.fecha_asignacion as fecha_ini
          from plani.tfuncionario_planilla fp
          inner join plani.tplanilla p on fp.id_planilla = p.id_planilla
          inner join plani.tcolumna_valor cv on cv.id_funcionario_planilla = fp.id_funcionario_planilla
          inner join orga.tuo_funcionario uofun on uofun.id_uo_funcionario = fp.id_uo_funcionario
          where cv.codigo_columna in (''SUBPRE'',''SUBNAT'',''SUBLAC'',''SUBSEP'') and cv.valor < ' || v_subsidio_actual || ' and cv.valor > 0
          and p.id_gestion = ' || v_planilla.id_gestion 
          	 || ' and uofun.id_funcionario = ' || p_id_funcionario || ' 
              and uofun.id_funcionario not in (
                  select id_funcionario
                  from plani.tfuncionario_planilla fp
                  inner join plani.tplanilla p
                      on p.id_planilla = fp.id_planilla
                  where 	fp.id_funcionario = uofun.id_funcionario and 
                          p.id_tipo_planilla = ' || v_planilla.id_tipo_planilla || ' and
                          p.id_gestion = ' || v_planilla.id_gestion || ')
          order by uofun.id_funcionario, uofun.fecha_asignacion desc')loop
        if (plani.f_tiene_contrato_activo(v_registros.id_funcionario,v_planilla.fecha_planilla)) then
    	  --En caso de que el empleado ya no trabaje para la empresa es probable que la cuenta bancaria tenga q ser null       
          o_id_cuenta_bancaria = plani.f_get_cuenta_bancaria_empleado(v_registros.id_funcionario, v_planilla.fecha_planilla);	
        end if;  	 
        
        v_existe = 'si';
        o_id_lugar = v_registros.id_lugar;
        o_id_uo_funcionario = v_registros.id_uo_funcionario;
        o_id_afp = NULL;
         
  			  	
    end loop;
    if (v_existe = 'no') then
    	raise exception 'No se puede añadir el funcionario a la planilla ya que no le corresponde retroactivo de subsidios';
    end if;
    return;
EXCEPTION
				
	WHEN OTHERS THEN
		v_resp='';
		v_resp = pxp.f_agrega_clave(v_resp,'mensaje',SQLERRM);
		v_resp = pxp.f_agrega_clave(v_resp,'codigo_error',SQLSTATE);
		v_resp = pxp.f_agrega_clave(v_resp,'procedimientos',v_nombre_funcion);
		raise exception '%',v_resp;
				        
END;
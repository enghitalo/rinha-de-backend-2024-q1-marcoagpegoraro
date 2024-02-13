module cli_ctrler

import db.pg
import vweb
import json 
import arrays 
import time
import math
// import option

import models 
import dtos

pub struct ClienteCxt {
	vweb.Context
	db_handle vweb.DatabasePool[pg.DB] = unsafe { nil }
pub mut:
	db pg.DB
}


@['/:id/transacoes'; post]
pub fn (mut app ClienteCxt) post_transacao(idRequest int) vweb.Result {
	transacao_dto := json.decode(dtos.TransacaoDto, app.req.data) or {
		app.set_status(422, '')
		return app.text('Failed to decode json, error: $err')
	}

	if !transacao_eh_valida(transacao_dto) {
		app.set_status(422, '')
		return app.text("")	
	}

	transacao_valor := i64(transacao_dto.valor) 
	resultado := app.db.exec_param_many('SELECT * from update_balance($1, $2, $3)', [idRequest.str(), transacao_dto.tipo.str(), transacao_valor.str()]) or { panic(err) }

	procedure_message := resultado[0].vals[0]
	// is_error := resultado[0].vals[1] or {panic(err)} 
	// saldo_cliente_string := resultado[0].vals[2] or {panic(err)}
	// limite_cliente_string := resultado[0].vals[3] or {panic(err)}
	// saldo_cliente := saldo_cliente_string.i64()
	// limite_cliente := limite_cliente_string.i64()	
	println(procedure_message)
	println(procedure_message == "Saldo do cliente atualizado com sucesso")
	// println(is_error)
	// println(saldo_cliente_string)
	// println(limite_cliente_string)



	// procedure_message := ''
	// is_error := ''
	// saldo_cliente := 0 
	// limite_cliente := 0
	// match resultado {
	// 	// If the result is Some, it contains a value
	// 	option.Some(rows) => {
	// 		// Use the rows here
	// 		// Iterate through the rows if needed
	// 		// for row in rows {
	// 		// 	// Access row data and process it
	// 		// 	println(row)
	// 		// }
	// 		procedure_message := rows[0].vals[0]
	// 		is_error := rows[0].vals[1] == 't'
	// 		saldo_cliente := rows[0].vals[2].i64() 
	// 		limite_cliente := rows[0].vals[3].i64()
	// 	}
	// 	// If the result is None, handle the case where the result is empty
	// 	option.None => {
	// 		println('No rows returned')
	// 		return app.text("")
	// 	}
	// }


	// procedure_message := resultado[0].vals[0]
	// is_error := resultado[0].vals[1] == 't'
	// saldo_cliente := resultado[0].vals[2].i64() 
	// limite_cliente := resultado[0].vals[3].i64()

	// if is_error  == 't'{
	// 	if procedure_message == 'Cliente não encontrado' {	
	// 		app.set_status(404, '')
	// 	} else if procedure_message == 'Limite foi ultrapassado' {
	// 		app.set_status(422, '')	
	// 	}
	// 	return app.text("")
	// }
	
	transacao := models.Transacao{
		id_cliente: idRequest
		valor: transacao_valor
		tipo: transacao_dto.tipo
		descricao: transacao_dto.descricao
		realizada_em: time.now().format_rfc3339()
	}

	sql app.db {
		insert transacao into models.Transacao
	}or {panic(err)}
	
	
	transacao_response_dto := dtos.TransacaoResponseDto{
		// limite: limite_cliente
		// saldo: saldo_cliente
		limite: 99
		saldo: 88
	}

	return app.json(transacao_response_dto)
}

@['/:idRequest/extrato'; get]
pub fn (mut app ClienteCxt) get_extrato(idRequest i64) vweb.Result {
	clientes := sql app.db {
	select from models.Cliente where id == idRequest
	} or {panic(err)}

	if clientes == [] {
		app.set_status(404, '')
		return app.text("")
	}

	cliente := clientes[0]

	transacoes := sql app.db {
		select from models.Transacao where id_cliente == idRequest order by realizada_em desc limit 10
	} or {panic(err)}

	transacoes_response_dto := arrays.map_indexed[models.Transacao, dtos.TransacaoDto](transacoes, fn (i int, e models.Transacao) dtos.TransacaoDto{
		return dtos.TransacaoDto{
			valor: e.valor
			tipo: e.tipo
			descricao: e.descricao
			realizada_em: e.realizada_em
		} 
	})

	extrato_response_dto := dtos.ExtratoResponseDto{
		saldo: dtos.SaldoDto{
			total: cliente.saldo
			data_extrato: time.now().format_rfc3339()
			limite: cliente.limite
		} 
		ultimas_transacoes: transacoes_response_dto
	}


	return app.json(extrato_response_dto)
}

fn transacao_eh_valida(transacao_dto dtos.TransacaoDto) bool{
	if math.fmod(transacao_dto.valor, 1) != 0 {
		return false
	}
	if transacao_dto.valor < 0 {
		return false
	}
	if transacao_dto.tipo != "c" && transacao_dto.tipo != "d" {
		return false
	} 
	if  transacao_dto.descricao == "" || transacao_dto.descricao.len > 10 {
		return false
	}
	return true
}

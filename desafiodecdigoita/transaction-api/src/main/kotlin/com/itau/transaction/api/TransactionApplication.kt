package com.itau.transaction.api

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.context.annotation.ComponentScan
import org.springframework.scheduling.annotation.EnableScheduling

@SpringBootApplication
@EnableScheduling
@ComponentScan(basePackages = ["com.itau.transaction"])
class TransactionApplication

fun main(args: Array<String>) {
    runApplication<TransactionApplication>(*args)
}
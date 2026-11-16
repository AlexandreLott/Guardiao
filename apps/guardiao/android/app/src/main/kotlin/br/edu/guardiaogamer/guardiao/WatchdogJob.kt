package br.edu.guardiaogamer.guardiao

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context

/**
 * Vigia do acompanhamento: uma tarefa do sistema que roda de tempos em tempos
 * e religa o [MonitorService] se ele não estiver de pé. Ela é guardada pelo
 * próprio Android e continua valendo depois que o aparelho reinicia, mesmo
 * quando o aviso de "aparelho ligado" não chega ao app.
 */
class WatchdogJob : JobService() {
    override fun onStartJob(params: JobParameters?): Boolean {
        if (MonitorConfig.isEnabled(this)) {
            try {
                MonitorService.start(this)
            } catch (_: Exception) {
                // O sistema pode recusar agora; a próxima rodada tenta de novo.
            }
        }
        return false
    }

    override fun onStopJob(params: JobParameters?): Boolean = false

    companion object {
        private const val JOB_ID = 7102
        private const val EVERY_MS = 15 * 60 * 1000L // o menor intervalo que o Android aceita

        /** Agenda o vigia (sem efeito se já estiver agendado). */
        fun schedule(context: Context) {
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            if (scheduler.getPendingJob(JOB_ID) != null) return
            val job = JobInfo.Builder(JOB_ID, ComponentName(context, WatchdogJob::class.java))
                .setPeriodic(EVERY_MS)
                .setPersisted(true) // sobrevive ao reinício do aparelho
                .build()
            try {
                scheduler.schedule(job)
            } catch (_: Exception) {
            }
        }

        fun cancel(context: Context) {
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            scheduler.cancel(JOB_ID)
        }
    }
}

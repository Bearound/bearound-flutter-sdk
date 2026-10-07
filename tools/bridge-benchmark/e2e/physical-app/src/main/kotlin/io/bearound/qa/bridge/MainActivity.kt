package io.bearound.qa.bridge

import android.app.Activity
import android.os.Bundle
import android.view.WindowManager
import android.widget.TextView
import org.json.JSONObject
import java.io.File
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.startCoroutine

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val text = TextView(this).apply { textSize = 18f; setPadding(24, 48, 24, 24) }
        setContentView(text)
        if (savedInstanceState != null) { text.text = "Restart the QA run with a fresh intent"; return }
        val runId = intent.getStringExtra("run_id") ?: "missing"
        if (intent.getBooleanExtra("model_probe_only", false)) {
            text.text = "Private model QA: running on worker thread"
            File(filesDir, "model-results.json").delete()
            Thread({
                val report = try {
                    check(runId.matches(Regex("[A-Za-z0-9._-]{1,80}")) && runId != "missing")
                    val dictionaryRows = intent.getBooleanExtra("dictionary_rows", false)
                    PhysicalModelProbe(this, intent.getBooleanExtra("packed_rows", false) || dictionaryRows,
                        dictionaryRows).run(runId)
                } catch (error: Exception) {
                    JSONObject().put("status", "error").put("runId", runId)
                        .put("error", "${error.javaClass.simpleName}: ${error.message}")
                }
                val temporary = File(filesDir, "model-results.tmp")
                temporary.writeText(report.toString(2))
                check(temporary.renameTo(File(filesDir, "model-results.json")))
                runOnUiThread { text.text = "Private model QA: ${report.getString("status")}\nRun: $runId" }
            }, "model-probe").start()
            return
        }
        val runner = PhysicalBridgeRun(this, runId) { text.text = it }
        File(filesDir, "results.json").delete()
        val work: suspend () -> Unit = {
            check(runId.matches(Regex("[A-Za-z0-9._-]{1,80}")) && runId != "missing") {
                "A bounded run_id intent extra is required"
            }
            runner.run()
        }
        work.startCoroutine(object : Continuation<Unit> {
            override val context = EmptyCoroutineContext
            override fun resumeWith(result: Result<Unit>) {
                runner.result.put("status", if (result.isSuccess) "success" else "error")
                runner.result.put("error", result.exceptionOrNull()?.let {
                    JSONObject().put("type", it.javaClass.simpleName).put("message", it.message)
                } ?: JSONObject.NULL)
                try {
                    val temporary = File(filesDir, "results.tmp")
                    temporary.writeText(runner.result.toString(2))
                    check(temporary.renameTo(File(filesDir, "results.json"))) { "Result rename failed" }
                    text.text = "Bridge QA: ${runner.result.getString("status")}\nRun: $runId\n" +
                        "Controls: ${runner.controls.length()}\nRounds: ${runner.rounds.length()}"
                } catch (error: Exception) {
                    text.text = "Result write failed: ${error.javaClass.simpleName}: ${error.message}"
                }
            }
        })
    }
}

package com.guilleme.reversewiki.export

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import androidx.core.content.FileProvider
import com.guilleme.reversewiki.model.PlaceAnalysis
import java.io.File
import java.io.FileOutputStream

object ExportService {
    fun sharePostcard(context: Context, imagePath: String, analysis: PlaceAnalysis) {
        val photo = BitmapFactory.decodeFile(imagePath) ?: return
        val output = Bitmap.createBitmap(1080, 1350, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val destination = android.graphics.Rect(0, 0, 1080, 1350)
        canvas.drawBitmap(photo, null, destination, Paint(Paint.ANTI_ALIAS_FLAG))
        canvas.drawRect(
            0f, 500f, 1080f, 1350f,
            Paint().apply {
                shader = LinearGradient(0f, 500f, 0f, 1350f, Color.TRANSPARENT, Color.argb(235, 0, 0, 0), Shader.TileMode.CLAMP)
            },
        )
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        paint.typeface = Typeface.DEFAULT_BOLD; paint.textSize = 64f
        var y = drawWrapped(canvas, analysis.fact.lieu, paint, 64f, 880f, 980f)
        paint.textSize = 38f
        drawWrapped(canvas, analysis.fact.verifiedFact, paint, 64f, y + 36f, 980f, maxLines = 8)
        val file = exportFile(context, "ReverseWiki-postcard.png")
        FileOutputStream(file).use { output.compress(Bitmap.CompressFormat.PNG, 100, it) }
        share(context, file, "image/png")
    }

    fun sharePdf(context: Context, imagePath: String, analysis: PlaceAnalysis, map: Bitmap?) {
        val photo = BitmapFactory.decodeFile(imagePath) ?: return
        val pdf = PdfDocument()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK }
        val width = 1240
        val height = 1754
        fun page(number: Int): Pair<PdfDocument.Page, Canvas> {
            val page = pdf.startPage(PdfDocument.PageInfo.Builder(width, height, number).create())
            page.canvas.drawColor(Color.WHITE)
            return page to page.canvas
        }

        val (firstPage, first) = page(1)
        first.drawBitmap(photo, null, android.graphics.Rect(70, 70, 1170, 720), paint)
        paint.typeface = Typeface.DEFAULT_BOLD; paint.textSize = 54f
        var y = drawWrapped(first, analysis.fact.lieu, paint, 70f, 800f, 1100f)
        paint.textSize = 30f
        drawWrapped(first, analysis.fact.verifiedFact, paint, 70f, y + 35f, 1100f, maxLines = 18)
        pdf.finishPage(firstPage)

        val (secondPage, second) = page(2)
        var secondY = 90f
        map?.let {
            second.drawBitmap(it, null, android.graphics.Rect(70, 70, 1170, 650), paint)
            secondY = 710f
        }
        paint.typeface = Typeface.DEFAULT_BOLD; paint.textSize = 38f
        second.drawText("Le récit courant", 70f, secondY, paint)
        paint.typeface = Typeface.DEFAULT; paint.textSize = 27f
        secondY = drawWrapped(second, analysis.fact.officialFact, paint, 70f, secondY + 50f, 1100f, maxLines = 18)
        paint.typeface = Typeface.DEFAULT_BOLD; paint.textSize = 34f
        second.drawText("Sources", 70f, secondY + 60f, paint)
        paint.typeface = Typeface.DEFAULT; paint.textSize = 23f
        var sourceY = secondY + 105f
        analysis.fact.sources.forEachIndexed { index, source ->
            sourceY = drawWrapped(second, "${index + 1}. $source", paint, 70f, sourceY, 1100f, maxLines = 3) + 12f
        }
        pdf.finishPage(secondPage)

        val file = exportFile(context, "ReverseWiki-${System.currentTimeMillis()}.pdf")
        FileOutputStream(file).use(pdf::writeTo)
        pdf.close()
        share(context, file, "application/pdf")
    }

    private fun drawWrapped(
        canvas: Canvas, text: String, paint: Paint, x: Float, startY: Float, maxWidth: Float,
        maxLines: Int = Int.MAX_VALUE,
    ): Float {
        val words = text.split(Regex("\\s+"))
        var line = ""
        var y = startY
        var lines = 0
        val step = paint.textSize * 1.25f
        for (word in words) {
            val candidate = if (line.isEmpty()) word else "$line $word"
            if (paint.measureText(candidate) > maxWidth && line.isNotEmpty()) {
                canvas.drawText(line, x, y, paint); y += step; lines++
                if (lines >= maxLines) break
                line = word
            } else line = candidate
        }
        if (line.isNotEmpty() && lines < maxLines) { canvas.drawText(line, x, y, paint); y += step }
        return y
    }

    private fun exportFile(context: Context, name: String): File =
        File(context.cacheDir, "exports").apply { mkdirs() }.resolve(name)

    private fun share(context: Context, file: File, mime: String) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
            type = mime; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }, "Partager"))
    }
}

package com.example.scan_assistant;

import android.content.ContentValues;
import android.content.Context;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.util.Base64;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
	private static final String CHANNEL = "scan_assistant/native";

	@Override
	public void configureFlutterEngine(FlutterEngine flutterEngine) {
		super.configureFlutterEngine(flutterEngine);

		new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
			.setMethodCallHandler((call, result) -> {
				if (call.method.equals("saveImage")) {
					String base64 = call.argument("bytes");
					String name = call.argument("name");
					boolean ok = saveImageToGallery(base64, name);
					result.success(ok);
				} else {
					result.notImplemented();
				}
			});
	}

	private boolean saveImageToGallery(String base64, String filename) {
		try {
			byte[] bytes = Base64.decode(base64, Base64.DEFAULT);

			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				ContentValues values = new ContentValues();
				values.put(MediaStore.Images.Media.DISPLAY_NAME, filename);
				values.put(MediaStore.Images.Media.MIME_TYPE, "image/png");
				values.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/ScanAssistant");

				Uri uri = getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
				if (uri == null) return false;
				OutputStream os = getContentResolver().openOutputStream(uri);
				if (os == null) return false;
				os.write(bytes);
				os.close();
				return true;
			} else {
				File pictures = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES);
				File dir = new File(pictures, "ScanAssistant");
				if (!dir.exists()) dir.mkdirs();
				File outFile = new File(dir, filename);
				FileOutputStream fos = new FileOutputStream(outFile);
				fos.write(bytes);
				fos.flush();
				fos.close();

				MediaScannerConnection.scanFile(getApplicationContext(), new String[]{outFile.getAbsolutePath()}, null, null);
				return true;
			}
		} catch (Exception e) {
			e.printStackTrace();
			return false;
		}
	}
}
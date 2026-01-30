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
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CaptureRequest;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import android.graphics.Bitmap;
import com.google.zxing.BinaryBitmap;
import com.google.zxing.LuminanceSource;
import com.google.zxing.MultiFormatReader;
import com.google.zxing.Result;
import com.google.zxing.common.HybridBinarizer;
import com.google.zxing.RGBLuminanceSource;
import com.google.zxing.PlanarYUVLuminanceSource;
import com.google.zxing.DecodeHintType;
import java.util.EnumMap;
import java.util.Map;
import java.util.Arrays;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
	private static final String CHANNEL = "scan_assistant/native";
	private static final Map<DecodeHintType, Object> DECODE_HINTS = new EnumMap<>(DecodeHintType.class);
	private static final MultiFormatReader reader = new MultiFormatReader();

	static {
		DECODE_HINTS.put(DecodeHintType.TRY_HARDER, Boolean.TRUE);
		DECODE_HINTS.put(DecodeHintType.POSSIBLE_FORMATS, Arrays.asList(
			com.google.zxing.BarcodeFormat.QR_CODE,
			com.google.zxing.BarcodeFormat.DATA_MATRIX,
			com.google.zxing.BarcodeFormat.CODE_128
		));
		reader.setHints(DECODE_HINTS);
	}

	@Override
	public void configureFlutterEngine(FlutterEngine flutterEngine) {
		super.configureFlutterEngine(flutterEngine);

		new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
			.setMethodCallHandler((call, result) -> {
				if (call.method.equals("saveImage")) {
					String base64 = call.argument("bytes");
					String name = call.argument("name");
					result.success(saveImageToGallery(base64, name));
				} else if (call.method.equals("decodeImage")) {
					String path = call.argument("path");
					result.success(decodeImageFile(path));
				} else if (call.method.equals("decodeImageBytes")) {
					byte[] bytes = call.argument("bytes");
					Integer w = call.argument("width");
					Integer h = call.argument("height");
					result.success(decodeImageBytes(bytes, w == null ? 0 : w, h == null ? 0 : h));
				} else if (call.method.equals("setZoom")) {
					Double scale = call.argument("scale");
					result.success(applyZoom(scale == null ? 1.0 : scale));
				} else if (call.method.equals("setExposure")) {
					Double delta = call.argument("delta");
					result.success(adjustExposure(delta == null ? 0.0 : delta));
				} else {
					result.notImplemented();
				}
			});
	}

	/**
	 * 高效解码逻辑
	 * 采用裁剪中心区域 + 双向(正反色)扫描策略
	 */
	private String decodeImageBytes(byte[] yuvBytes, int width, int height) {
		if (yuvBytes == null || width <= 0 || height <= 0) return null;
		
		try {
			// 为了极致性能，我们只扫描画面中心的 70% 区域，这能过滤边缘噪点并提升速度
			int cropW = (int)(width * 0.7);
			int cropH = (int)(height * 0.7);
			int left = (width - cropW) / 2;
			int top = (height - cropH) / 2;

			PlanarYUVLuminanceSource source = new PlanarYUVLuminanceSource(
				yuvBytes, width, height, left, top, cropW, cropH, false
			);

			// 1. 尝试常规识别
			try {
				Result result = reader.decodeWithState(new BinaryBitmap(new HybridBinarizer(source)));
				return result.getText();
			} catch (Exception ignored) {}

			// 2. 核心补救：反色识别 (针对黑底蓝码秒出的关键)
			try {
				// ZXing 的 source.invert() 非常高效，只是对每个像素做了一次简单的 ~ 操作
				Result result = reader.decodeWithState(new BinaryBitmap(new HybridBinarizer(source.invert())));
				return result.getText();
			} catch (Exception ignored) {}

		} catch (Exception e) {
			Log.e("Scan", "Decode error", e);
		} finally {
			reader.reset();
		}
		return null;
	}

	private String decodeImageFile(String path) {
		try {
			Bitmap bitmap = BitmapFactory.decodeFile(path);
			if (bitmap == null) return null;
			int width = bitmap.getWidth();
			int height = bitmap.getHeight();
			int[] pixels = new int[width * height];
			bitmap.getPixels(pixels, 0, width, 0, 0, width, height);
			RGBLuminanceSource source = new RGBLuminanceSource(width, height, pixels);
			
			try {
				return reader.decodeWithState(new BinaryBitmap(new HybridBinarizer(source))).getText();
			} catch (Exception e) {
				try {
					return reader.decodeWithState(new BinaryBitmap(new HybridBinarizer(source.invert()))).getText();
				} catch (Exception e2) {
					return null;
				}
			}
		} catch (Exception e) {
			return null;
		} finally {
			reader.reset();
		}
	}

	private String selectBackCamera(CameraManager cameraManager, String[] cameraIdList) {
		try {
			for (String cameraId : cameraIdList) {
				CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(cameraId);
				Integer facing = characteristics.get(CameraCharacteristics.LENS_FACING);
				if (facing != null && facing == CameraCharacteristics.LENS_FACING_BACK) return cameraId;
			}
		} catch (Exception e) {}
		return null;
	}

	private boolean adjustExposure(double delta) {
		try {
			CameraManager cameraManager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
			if (cameraManager == null) return false;
			String[] ids = cameraManager.getCameraIdList();
			if (ids.length == 0) return false;
			String cameraId = selectBackCamera(cameraManager, ids);
			if (cameraId == null) cameraId = ids[0];
			CameraCharacteristics chars = cameraManager.getCameraCharacteristics(cameraId);
			int[] aeModes = chars.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_MODES);
			return aeModes != null && aeModes.length > 0;
		} catch (Exception e) {
			return false;
		}
	}

	private boolean applyZoom(double scale) {
		try {
			CameraManager cameraManager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
			if (cameraManager == null) return false;
			String[] ids = cameraManager.getCameraIdList();
			if (ids.length == 0) return false;
			String cameraId = selectBackCamera(cameraManager, ids);
			if (cameraId == null) cameraId = ids[0];
			CameraCharacteristics chars = cameraManager.getCameraCharacteristics(cameraId);
			Float maxZoom = chars.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM);
			if (maxZoom == null) return false;
			return scale <= maxZoom;
		} catch (Exception e) {
			return false;
		}
	}

	private boolean saveImageToGallery(String base64, String filename) {
		try {
			if (base64 == null) return false;
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
			return false;
		}
	}
}
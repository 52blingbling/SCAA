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
	private static final String TAG = "ScanAssistant";
	private static final Map<DecodeHintType, Object> DECODE_HINTS = new EnumMap<>(DecodeHintType.class);

	static {
		DECODE_HINTS.put(DecodeHintType.TRY_HARDER, Boolean.TRUE);
		// 移除对 QR_CODE 的单一限制，支持 Data Matrix 和 条形码等全格式识别
		DECODE_HINTS.put(DecodeHintType.POSSIBLE_FORMATS, Arrays.asList(
			com.google.zxing.BarcodeFormat.QR_CODE,
			com.google.zxing.BarcodeFormat.DATA_MATRIX,
			com.google.zxing.BarcodeFormat.CODE_128,
			com.google.zxing.BarcodeFormat.EAN_13
		));
	}

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
				} else if (call.method.equals("decodeImage")) {
					String path = call.argument("path");
					String decoded = decodeImageFile(path);
					result.success(decoded);
				} else if (call.method.equals("setFocusMode")) {
					boolean ok = configureContinuousFocus();
					result.success(ok);
				} else if (call.method.equals("focusAt")) {
					Double x = call.argument("x");
					Double y = call.argument("y");
					boolean ok = focusAtPoint(x == null ? 0.5 : x, y == null ? 0.5 : y);
					result.success(ok);
				} else if (call.method.equals("setExposure")) {
					Double delta = call.argument("delta");
					boolean ok = adjustExposure(delta == null ? 0.0 : delta);
					result.success(ok);
				} else if (call.method.equals("setZoom")) {
					Double scale = call.argument("scale");
					boolean ok = applyZoom(scale == null ? 1.0 : scale);
					result.success(ok);
				} else if (call.method.equals("decodeImageBytes")) {
					byte[] bytes = call.argument("bytes");
					Integer w = call.argument("width");
					Integer h = call.argument("height");
					String decoded = decodeImageBytes(bytes, w == null ? 0 : w, h == null ? 0 : h);
					result.success(decoded);
				} else {
					result.notImplemented();
				}
			});
	}

	private String decodeImageBytes(byte[] yuvBytes, int width, int height) {
		try {
			if (yuvBytes == null || width <= 0 || height <= 0) return null;
			PlanarYUVLuminanceSource source = new PlanarYUVLuminanceSource(yuvBytes, width, height, 0, 0, width, height, false);
			BinaryBitmap binaryBitmap = new BinaryBitmap(new HybridBinarizer(source));
			// 使用全格式解码器
			Result result = new MultiFormatReader().decode(binaryBitmap, DECODE_HINTS);
			return result == null ? null : result.getText();
		} catch (Exception e) {
			return null;
		}
	}

	private boolean configureContinuousFocus() {
		try {
			CameraManager cameraManager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
			if (cameraManager == null) return false;
			String[] cameraIdList = cameraManager.getCameraIdList();
			if (cameraIdList.length == 0) return false;
			String cameraId = selectBackCamera(cameraManager, cameraIdList);
			if (cameraId == null) cameraId = cameraIdList[0];
			CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(cameraId);
			int[] afModes = characteristics.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES);
			if (afModes == null || afModes.length == 0) return false;
			boolean supportsContinuous = false;
			for (int mode : afModes) {
				if (mode == CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE) {
					supportsContinuous = true;
					break;
				}
			}
			return supportsContinuous;
		} catch (Exception e) {
			return false;
		}
	}

	private String selectBackCamera(CameraManager cameraManager, String[] cameraIdList) {
		try {
			for (String cameraId : cameraIdList) {
				CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(cameraId);
				Integer facing = characteristics.get(CameraCharacteristics.LENS_FACING);
				if (facing != null && facing == CameraCharacteristics.LENS_FACING_BACK) return cameraId;
			}
		} catch (Exception e) { }
		return null;
	}

	private void logAvailableFocusModes(int[] modes) { }

	private String decodeImageFile(String path) {
		try {
			Bitmap bitmap = BitmapFactory.decodeFile(path);
			if (bitmap == null) return null;
			int width = bitmap.getWidth();
			int height = bitmap.getHeight();
			int[] pixels = new int[width * height];
			bitmap.getPixels(pixels, 0, width, 0, 0, width, height);
			LuminanceSource source = new RGBLuminanceSource(width, height, pixels);
			BinaryBitmap binaryBitmap = new BinaryBitmap(new HybridBinarizer(source));
			Result result = new MultiFormatReader().decode(binaryBitmap, DECODE_HINTS);
			return result == null ? null : result.getText();
		} catch (Exception e) {
			return null;
		}
	}

	private boolean focusAtPoint(double nx, double ny) {
		try {
			CameraManager cameraManager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
			if (cameraManager == null) return false;
			String[] ids = cameraManager.getCameraIdList();
			if (ids.length == 0) return false;
			String cameraId = selectBackCamera(cameraManager, ids);
			if (cameraId == null) cameraId = ids[0];
			CameraCharacteristics chars = cameraManager.getCameraCharacteristics(cameraId);
			int[] afModes = chars.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES);
			if (afModes == null) return false;
			boolean hasAuto = false;
			for (int m : afModes) if (m == CaptureRequest.CONTROL_AF_MODE_AUTO || m == CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE) hasAuto = true;
			return hasAuto;
		} catch (Exception e) {
			return false;
		}
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
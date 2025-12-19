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

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
	private static final String CHANNEL = "scan_assistant/native";
	private static final String TAG = "ScanAssistant";

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
					// 配置 Camera2 连续对焦模式
					boolean ok = configureContinuousFocus();
					result.success(ok);
				} else {
					result.notImplemented();
				}
			});
	}

	private boolean configureContinuousFocus() {
		try {
			// 获取 CameraManager 和系统服务
			CameraManager cameraManager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
			if (cameraManager == null) {
				Log.w(TAG, "CameraManager unavailable");
				return false;
			}

			// 获取可用摄像头列表
			String[] cameraIdList = cameraManager.getCameraIdList();
			if (cameraIdList.length == 0) {
				Log.w(TAG, "No cameras found");
				return false;
			}

			// 优先选择后置摄像头 (LENS_FACING_BACK = 0)
			String cameraId = selectBackCamera(cameraManager, cameraIdList);
			if (cameraId == null) {
				cameraId = cameraIdList[0]; // 回退：使用第一个摄像头
			}

			// 获取摄像头特性
			CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(cameraId);
			
			// 检查支持的自动对焦模式
			int[] afModes = characteristics.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES);
			if (afModes == null || afModes.length == 0) {
				Log.w(TAG, "No AF modes available");
				return false;
			}

			// 验证是否支持连续对焦 (CONTROL_AF_MODE_CONTINUOUS_PICTURE = 4)
			boolean supportsContinuous = false;
			for (int mode : afModes) {
				if (mode == CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE) {
					supportsContinuous = true;
					break;
				}
			}

			if (supportsContinuous) {
				Log.d(TAG, "✓ Camera supports FOCUS_MODE_CONTINUOUS_PICTURE (mode 4)");
				Log.d(TAG, "  Camera ID: " + cameraId);
				logAvailableFocusModes(afModes);
				// 注意：实际应用焦点模式需要在 CaptureRequest 中设置。
				// mobile_scanner 库应在其内部相机会话中应用此配置。
				// 推荐的设置：request.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE);
				return true;
			} else {
				Log.w(TAG, "✗ Camera does NOT support continuous focus mode");
				logAvailableFocusModes(afModes);
				return false;
			}

		} catch (Exception e) {
			Log.e(TAG, "Error configuring camera focus: " + e.getMessage(), e);
			return false;
		}
	}

	/**
	 * 选择后置摄像头 ID
	 */
	private String selectBackCamera(CameraManager cameraManager, String[] cameraIdList) {
		try {
			for (String cameraId : cameraIdList) {
				CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(cameraId);
				Integer facing = characteristics.get(CameraCharacteristics.LENS_FACING);
				// LENS_FACING_BACK = 0
				if (facing != null && facing == CameraCharacteristics.LENS_FACING_BACK) {
					return cameraId;
				}
			}
		} catch (Exception e) {
			Log.w(TAG, "Error selecting back camera: " + e.getMessage());
		}
		return null;
	}

	/**
	 * 输出日志：当前支持的所有焦点模式
	 */
	private void logAvailableFocusModes(int[] modes) {
		if (modes == null) return;
		StringBuilder sb = new StringBuilder("Available AF modes: ");
		for (int mode : modes) {
			switch (mode) {
				case CaptureRequest.CONTROL_AF_MODE_OFF:
					sb.append("OFF(0) ");
					break;
				case CaptureRequest.CONTROL_AF_MODE_AUTO:
					sb.append("AUTO(1) ");
					break;
				case CaptureRequest.CONTROL_AF_MODE_MACRO:
					sb.append("MACRO(2) ");
					break;
				case CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO:
					sb.append("CONTINUOUS_VIDEO(3) ");
					break;
				case CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE:
					sb.append("CONTINUOUS_PICTURE(4) ");
					break;
				case CaptureRequest.CONTROL_AF_MODE_EDOF:
					sb.append("EDOF(5) ");
					break;
				default:
					sb.append("UNKNOWN(").append(mode).append(") ");
			}
		}
		Log.d(TAG, sb.toString());
	}

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
			Result result = new MultiFormatReader().decode(binaryBitmap);
			return result == null ? null : result.getText();
		} catch (Exception e) {
			e.printStackTrace();
			return null;
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
			e.printStackTrace();
			return false;
		}
	}
}
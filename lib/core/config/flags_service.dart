import 'package:cloud_firestore/cloud_firestore.dart';

class FlagsService {
	static final FlagsService instance = FlagsService._();
	FlagsService._();

	bool? _bypassKycCache;

	Future<bool> bypassKyc() async {
		if (_bypassKycCache != null) return _bypassKycCache!;
		try {
			final doc = await FirebaseFirestore.instance.collection('_config').doc('flags').get(const GetOptions(source: Source.serverAndCache));
			_bypassKycCache = (doc.data()?['bypassKyc'] == true);
			return _bypassKycCache!;
		} catch (_) {
			return false;
		}
	}
}


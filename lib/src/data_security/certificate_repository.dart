import 'dart:collection';

import 'package:adhoc_plugin/src/data_security/certificate.dart';


class CertificateRepository {
  HashMap<String, Certificate> _repository;

  CertificateRepository() {
    this._repository = HashMap();
    this._manageCertificates();
  }

/*------------------------------Public methods--------------------------------*/

  void addCertificate(Certificate certificate) {
    _repository.putIfAbsent(certificate.owner, () => certificate);
  }

  void removeCertificate(String label) {
    _repository.remove(label);
  }

  Certificate getCertificate(String label) {
    return _repository[label];
  }

  bool containCertificate(String label) {
    return _repository.containsKey(label);
  }

/*------------------------------Private methods-------------------------------*/

  void _manageCertificates() {
    // Periodically check wether a certificate validity has expired or not
  }
}

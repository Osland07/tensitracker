<?php

namespace App\Controllers\Admin;

use App\Controllers\BaseController;
use App\Models\ScreeningModel;
use App\Models\ScreeningDetailModel;
use App\Models\UserProfileModel;
use App\Models\RiskLevelModel;
use Dompdf\Dompdf;

class AdminHistoryController extends BaseController
{
    protected $screeningModel;
    protected $screeningDetailModel;
    protected $profileModel;
    protected $riskLevelModel;

    public function __construct()
    {
        $this->screeningModel = new ScreeningModel();
        $this->screeningDetailModel = new ScreeningDetailModel();
        $this->profileModel = new UserProfileModel();
        $this->riskLevelModel = new RiskLevelModel();
    }

    public function index()
    {
        $data = [
            'title'   => 'Riwayat Skrining',
            'history' => $this->screeningModel->orderBy('created_at', 'DESC')->findAll(),
        ];
        return view('Admin/history/index', $data);
    }

    public function detail($id)
    {
        $screening = $this->screeningModel->find($id);

        if (!$screening) {
            return redirect()->to('/admin/history')->with('error', 'Data tidak ditemukan.');
        }

        // Ambil Profil User terkait
        $profile = $this->profileModel->where('user_id', $screening['user_id'])->first();

        // Ambil Risk Level Data
        $riskLevelData = $this->riskLevelModel->where('name', $screening['result_level'])->first();

        // Ambil Detail Jawaban
        $details = $this->screeningDetailModel->select('risk_factors.code, risk_factors.name, risk_factors.question_text')
                                              ->join('risk_factors', 'risk_factors.id = screening_details.risk_factor_id')
                                              ->where('screening_id', $id)
                                              ->findAll();

        // Hitung BMI & Tensi (Snapshot Profil saat ini)
        $bmi = '-';
        if ($profile && $profile['height'] && $profile['weight']) {
            $h = $profile['height'] / 100;
            $bmi = number_format($profile['weight'] / ($h * $h), 1);
        }
        
        $tensi = '-';
        if ($profile && $profile['systolic'] && $profile['diastolic']) {
            $tensi = $profile['systolic'] . '/' . $profile['diastolic'] . ' mmHg';
        }

        $data = [
            'title'         => 'Detail Riwayat Skrining',
            'screening'     => $screening,
            'profile'       => $profile,
            'riskLevelData' => $riskLevelData,
            'details'       => $details,
            'bmi'           => $bmi,
            'tensi'         => $tensi
        ];

        return view('Admin/history/detail', $data);
    }

    public function delete($id)
    {
        $this->screeningModel->delete($id);
        return redirect()->to('/admin/history')->with('message', 'Riwayat berhasil dihapus.');
    }

    public function printPDF()
    {
        $data = ['history' => $this->screeningModel->orderBy('created_at', 'DESC')->findAll()];
        
        $dompdf = new Dompdf();
        $dompdf->loadHtml(view('Admin/history/print', $data));
        $dompdf->setPaper('A4', 'portrait');
        $dompdf->render();
        $dompdf->stream('laporan-riwayat.pdf', ['Attachment' => 0]);
    }
}

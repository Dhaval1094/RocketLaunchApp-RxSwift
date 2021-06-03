//
//  HomeViewController.swift

//  Created by Dhaval Trivedi on 11/04/21.
//

import UIKit
import RxSwift
import Action

class HomeViewController: UIViewController, Alertable {
    
    //MARK: - IBOutlets
    @IBOutlet weak var btnLoadMore: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var detailContainerView: UIView!
    @IBOutlet weak var textView: UITextView!
    
    //MARK: - Variables
    private var vm: HomeVMType!
    private var disposeBag = DisposeBag()
    private var launchData: [Launches]?
    private var selectedObj: Launches?
    private var rocketData: Rocket?
    
    //MARK: - ViewControllet Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        vm = HomeVM()
        configureUI()
        bindVM()
    }
    
    //MARK: - Methods
    func configureUI() {
        collectionView.registerCell(HomeCollViewCell.self)
        btnLoadMore.isEnabled = false
        launchData = [Launches]()
        title = NavigationTitle.HomeViewTitle
    }
    
    func bindVM() {
        
        btnLoadMore.rx.action = CocoaAction(workFactory: { () -> Observable<Void> in
            guard let cursor = self.vm.lastCursor else {
                return .empty()
            }
            let dto = FetchMoreLaunchesDTO.init(cursor: cursor)
            self.vm.onLoadMoreData.execute(dto)
          return .empty()
        })
        
        vm.launchData
            .subscribe(onNext: handleRocketLaunchData())
            .disposed(by: disposeBag)
        
        vm.rocketData
            .subscribe(onNext: handleRocketDetailsData())
            .disposed(by: disposeBag)
        
        vm.state.isCompleteByAction()
          .asDriver(onErrorJustReturn: nil)
          .drive(onNext: { [weak self] type in
            guard let self = self else { return }
            if let type = type {
              switch type {
              case .fetchLauncheDetail:
                //Do something on completion of fetch
                break
              case .fetchRocketDetail:
                //show rocket details
                if let r = self.rocketData?.rocket, let name = r.name, let type = r.type, let desc = self.selectedObj?.mission?.name, let code = self.selectedObj?.site {
                    self.textView.text = "\u{1F680} Name: \(name) \r\n\u{1F680} Type: \(type) \r\n\u{1F680} Code: \(code) \r\n\u{1F680} Desc: \(desc)"
                }
              }
            }
          })
          .disposed(by: disposeBag)

        vm.error
          .asDriver(onErrorJustReturn: nil)
          .drive(onNext: handleError())
          .disposed(by: disposeBag)
        
        //Call API
        vm.onGetLaunchData.execute()
        
    }
}

//MARK: - Handlers
private extension HomeViewController {
    func handleRocketLaunchData() -> (([Launches]?) -> Void)? {
        return { [weak self] launches in
            guard let strongSelf = self, let newLaunches = launches else { return }
            strongSelf.launchData?.append(contentsOf: newLaunches)
            strongSelf.collectionView.reloadData()
        }
    }
    func handleRocketDetailsData() -> ((Rocket?) -> Void)? {
        return { [weak self] rocket in
            guard let strongSelf = self, let rocket = rocket else { return }
            strongSelf.rocketData = rocket
        }
    }
    func handleState() -> SingleResult<Bool> {
      return { isComplete in
        //Get the completion state of the API call
      }
    }

    func handleError() -> SingleResult<Error?> {
      return { [weak self] error in
        guard let self = self, let error = error else { return }
        self.showAlert(message: error.localizedDescription)
      }
    }
}


//MARK: - UICollection View Delegate/Datasource
extension HomeViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return launchData?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(HomeCollViewCell.self, for: indexPath)
        guard let obj = launchData?[indexPath.item] else {
            return cell
        }
        cell.configureWith(obj: obj)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.view.frame.size.width / 2.3, height: self.view.frame.size.height/2.9)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.row == launchData!.count - 1 {
            btnLoadMore.isEnabled = true
        } else {
            btnLoadMore.isEnabled = false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let obj = launchData?[indexPath.item], let launchId = obj.id else {
            return
        }
        self.selectedObj = obj
        let dto = FetchLaunchDetailsDTO.init(launchId: launchId)
        UIView.animate(withDuration: 0.3) {
            self.detailContainerView.alpha = 1.0
        }
        textView.text = "Loading rocket detail...\u{1F680} \u{1F680} \u{1F680}"
        vm.onLaunchDetails.execute(dto)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if detailContainerView.alpha == 1.0 {
            UIView.animate(withDuration: 0.3) {
                self.detailContainerView.alpha = 0.0
            }
        }
    }
    
}

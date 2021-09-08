pragma solidity ^0.5.10;

import "./octapay_mainet_publish.sol";
import "./IERC20.sol";


// implemetation of safe math 

// implementation of events s


/////////////////////////////////////////////////////////////////////Payzus Staking Contract Start////////////////////////////////////////////////////////////////////////////////////////////////////////



contract PZS_Staking {

    address public stakingPooladmin = 0x3793f758a36c04B51a520a59520e4d845f94F9F2 ;
    address public owner ;
    OCTAPAY public octapay;
                    
   
    ERC20Interface public pzsContractAddress;
    
    
    uint public poolBatchNumber;
    string public poolBatchType = 'Flexible';
   
   
    uint public MINTING_VELOCITY = 2;                                    // MINTING_VELOCITY = 0.0000002;
    uint public MINTING_VELOCITY_ACCURACY_RATIO = 10000000 ;
    
    uint public HOUSE_EDGE = 20 ;                                       //  HOUSE_EDGE = 20%
    uint public HOUSE_EDGE_ACC_RATIO = 100 ;
    
                   
    
    uint public MINIMUM_PZS_STAKING_AMT = 1000000000000000000000 ; //stake pzs = 100000 for 3 minutes poolExpirationPeriod testing // place 1000 in final deployement
    
    bool mintingOn = false; 
    bool public tokensMinted = false;
  
    bool public isPoolExpired = false;  // for testing purpose
    
    bool public stopContract = false ;
      
    address public octapayContractAddress ;
    
     
    uint public deployTime = now;
    uint public poolExpirationPeriod = now + 4 hours;   //  place 30 days in final deployement
    uint public minimumStakingDuration = 60 minutes;     // place 5 hours in final deployment    

   
   
    address[] public stakers;
    address[] public stakersForHistory;
    
    uint  public stakersLength ; // total number of stakers
    uint  public stakersLengthHistory;
    
    uint public totalPayzusStaked ;           // Total Payzus Staked
    uint public totalPayzusHistory ; 
     
     
     
     
     uint public totalOctapayMintedInCurrentPool ;
     uint public totaloctaPayToMintForCurrentBatch;
    
    
    bool public redeemReserveOctaByAdmin = false ;    // added new
    
    uint public amountResrveOctapayTemp ;
    
    
    mapping(address => uint) public stakingBalance;
    
    mapping(address => uint) public stakingBalanceHistory;
   
    
    mapping(address => uint) public expectedOctapayReceivedByAnAddress ;        // For e.g. 1 PZS staked for 30 days : which minted 0.5 Octapay
    mapping(address => uint) public reserveOctapay ;                             //  totalOctapayMintedByAnAddress = 0.5 , reserveOctapay = 0.1  , expectedOctapayReceivedByAnAddress = 0.4 where 0.1 is HOUSE_EDGE related reserve Octa Token
    mapping(address => uint) public reserveOctpayMintedByAnAddress ;                                                                               //Related to HOUSE_EDGE
    mapping(address => uint) public totalOctapayMintedByAnAddress ;

    
    
    mapping(address => bool) public hasStaked;
    mapping(address => bool) public isStaking;
    mapping(address => uint) public stakeTime;
    
    mapping(address => bool) public isTokenRedeemed;
    
    mapping(address => uint) public yourStackingDurationPerBatch ; 
    
    
    
    //////////////////////////////////////////////////////////////////////////////EVENT DECLERATION//////////////////////////////////////////////////////////////////////////////////////////////////////
    
      event Staked(address indexed _from, uint _value);

      event UnStaked(address indexed _from, uint _value);
 
    
     //////////////////////////////////////////////////////////////////////////////Constructor Function///////////////////////////////////////////////////////////////////////////////////////////////////
     

     
      constructor(address _octapay , address _pzsContractAddress , uint _poolBatchNumber) public {
         octapayContractAddress = _octapay;
        octapay = OCTAPAY(_octapay);
        pzsContractAddress = ERC20Interface(_pzsContractAddress);
        poolBatchNumber = _poolBatchNumber ;
      

        owner  = msg.sender;

        
    }


//////////////////////////////////////////////////////////////////////////////////////Modifier Definitations////////////////////////////////////////////////////////////////////////////////////////////



   // Admin address should be fixed ,irrespective of who is deployer of the Payzus Staking Pool contract 
  //Delpoyer of the Payzus Staking Pool Contract may change time to time every time Staking Pool Contract is deployed
 // But main Admin should always be hardcoded as ,without it ,Octpay "Minting" function might get hacked 

    
    
    modifier onlyAdmin {
        require (msg.sender == stakingPooladmin , 'Only Admin has right to execute this function');
        _;
        
    }
    
    
/////////////////////////////////////////////////////////////////////////POOL EXPIRATION PERIOD TESTING FUNCTION/////////////////////////////////////


function isPoolExpirationTimeAchieved () public returns(bool) {
    
    if (now >=  poolExpirationPeriod){
        
          isPoolExpired = true;
    }
    
    
}


//////////////////////////////////////////////////////////////////////////////////////Staking Function//////////////////////////////////////////////////////////////////////////////////////////////////




     function stakeTokens(uint _amount) public  {
         
       require ( now < poolExpirationPeriod - minimumStakingDuration  , 'Too late!You are not allowed to stake now,Wait for next Batch!');
       
       require( _amount >= MINIMUM_PZS_STAKING_AMT , "Minimum Payzus Need to be staked is 1000 PZS");
       
       require ( (hasStaked[msg.sender] == false)  && (isStaking[msg.sender] == false), "You have already staked once in this pool.You cannot staked again.Wait for next batch") ;
      
       pzsContractAddress.transferFrom(msg.sender, address(this), _amount);
 

        // Update staking balance
        stakingBalance[msg.sender] =  _amount;
        stakingBalanceHistory[msg.sender] = _amount;

        // Add user to stakers array *only* if they haven't staked or is staking already
        
        if((hasStaked[msg.sender] == false) && (isStaking[msg.sender] == false)) {
            stakers.push(msg.sender);
            stakersForHistory.push(msg.sender);
        }



        // Update staking status
        isStaking[msg.sender] = true;
        hasStaked[msg.sender] = true;
        stakeTime[msg.sender] = now ;
        
        // calculation of total duration one has staked their Payzus Tokens in current pool :This is logic for fixed staking pool ,
        //as in this staking pool users cannot withdraw staked Payzus tokens  before Pool Expiratiom period is achieved
        
         uint stackingDuration = poolExpirationPeriod - now ;
       
         yourStackingDurationPerBatch[msg.sender] =  stackingDuration ; 
         
         emit Staked(msg.sender, _amount);
         

    }
    
    
    //////////////////////////////////////////////////////////////////////////////////////Octapay Minting Function //////////////////////////////////////////////////////////////////////////////////////////////////
    

        
    function startOctapayTokenMinting() public onlyAdmin {
        
      
      require ((now > poolExpirationPeriod) && (tokensMinted == false) && (stopContract == false) , "Octapay Token Released Threshold Time hasnt crossed yet");
        
       
        calculateTotalPayzusStaked();
       
       calculateOctapayEarnedByAnAddress();

       uint amount = octaPayToMintForCurrentBatch();
       
       
       totalOctapayMintedInCurrentPool = amount ;
       
       
       octapay.mintOctapay(amount);
    
       
       // implentation of one function  remaning where we have to make sure octapay tokens minted ,then only it would be safe to make tokensMinted = true;
       tokensMinted = true;
       
       
        
    }

        
        
        function octaPayToMintForCurrentBatch () private returns (uint) {
        
    
        
         for (uint i=0; i <stakers.length; i++) { 
             
            address recipient = stakers[i];
            uint balance = totalOctapayMintedByAnAddress[recipient];
            
            totaloctaPayToMintForCurrentBatch = totaloctaPayToMintForCurrentBatch + balance ;
        
         }
         
           return totaloctaPayToMintForCurrentBatch ;
        
    
    }
 
        

        
      
      function calculateOctapayEarnedByAnAddress()  private  {
          
          for (uint i=0; i < stakers.length; i++) { 
                  
              address recipient = stakers[i];
              
              uint balance = stakingBalance[recipient];
                  
           
       
           
     totalOctapayMintedByAnAddress[recipient] =   (totalOctapayMintedByAnAddress[recipient]) + ((balance * yourStackingDurationPerBatch[recipient] * MINTING_VELOCITY)/MINTING_VELOCITY_ACCURACY_RATIO) ;
     
     reserveOctpayMintedByAnAddress[recipient] =    (HOUSE_EDGE*totalOctapayMintedByAnAddress[recipient])/HOUSE_EDGE_ACC_RATIO;    
     
     expectedOctapayReceivedByAnAddress[recipient] = totalOctapayMintedByAnAddress[recipient] -  reserveOctpayMintedByAnAddress[recipient];      
      
     reserveOctapay[octapayContractAddress] =   reserveOctapay[octapayContractAddress] + reserveOctpayMintedByAnAddress[recipient];    
     
     
           
          }
                    
                  
    }
    
    
    /////////////////////////////////////////////////////////////////////////////////////////////////////////REDEEM TOKENS///////////////////////////////////////////////////////////////////////////////////////////////
    

    
    /////// Reedem and transfer Reserve Octpay to Octpay Smart Contract/////////////////////////////////////////////////////////////////////////////////////////////////////////////
      
      
      function redeemReserveOctapayTokens() public onlyAdmin {
          
         require((now > poolExpirationPeriod) && (tokensMinted == true) && (stopContract == false) && (redeemReserveOctaByAdmin == false), "Staking pool Expiration period hasnt been achieved yet or tokens not minted yet");
          
          
           uint balance = reserveOctapay[octapayContractAddress];
           
           require(redeemReserveOctaByAdmin == false ,'Admin has already redeemed reserved Octapay for current batch') ;
           
           if(balance > 0) {
               
               
               octapay.transfer(octapayContractAddress ,balance); 
               

               reserveOctapay[octapayContractAddress] = 0; 
               
               redeemReserveOctaByAdmin = true ;
               
           }

          
      }
      
 

    
    
    
      /////// Redeem  Octapay Tokens by an Address /////////////////////////////////////////////////////////////////////////////////////////////////////////////
      
      
      function redeemOctapayTokens() public {
          
         require((now > poolExpirationPeriod) && (tokensMinted == true)  && (stopContract == false) && (hasStaked[msg.sender] == true ) && (isTokenRedeemed[msg.sender] == false), "Staking pool Expiration period hasnt been achieved yet or tokens not minted yet");
          
          
           uint balance = expectedOctapayReceivedByAnAddress[msg.sender];
           
           if(balance > 0) {
               
               octapay.transfer(msg.sender ,balance);  
               
             // deductReserveOctapay(balance);
               
              expectedOctapayReceivedByAnAddress[msg.sender] = 0 ;
              
              isTokenRedeemed[msg.sender] == true ;
           }

      }
      

    
    


    
     //////////////////////////////////////////////////////////////////////////////////////Unstaking the PZS Tokens Function //////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////Flexible Pool////////////////////////////////////////////////
    
    // Unstaking Tokens (Withdraw)
    function unstakeTokens() public {
        
      
        // Fetch staking balance
        uint balance = stakingBalance[msg.sender];

        // Require amount greater than 0
        require((balance > 0) || (stopContract == true) , "staking balance cannot be 0 or you cannot stake before pool expiration period");
        
        
       
        if(now < poolExpirationPeriod - minimumStakingDuration) {
        
        uint stackingDuration = poolExpirationPeriod - now ;
        yourStackingDurationPerBatch[msg.sender] =  stackingDuration ; 

        
        }
        

        // Transfer  PZS tokens to this contract for staking
          ERC20Interface(pzsContractAddress).transfer(msg.sender, balance);

        // Reset staking balance
        stakingBalance[msg.sender] = 0;

        // Update staking status
        isStaking[msg.sender] = false;
       
        
         emit UnStaked(msg.sender, balance);
    } 
    
    
    
    
    ///////////////////////////////////////////////////////////////////Calculate total no of Payzus Staked/////////////////////////////////////////////////////////////////////////////////////////////////
    

       
       function  calculateTotalPayzusStaked() private returns(uint) {
         
             for (uint i=0; i < stakersForHistory.length; i++) { 
                  
              
              stakersLengthHistory = stakersForHistory.length ;
              
              address recipient = stakersForHistory[i];
              
               totalPayzusStaked  = totalPayzusStaked +  stakingBalanceHistory[recipient];
              
             }    
             
             return totalPayzusStaked ;
           
       }
   
       ///////////////////////////////////////////////////////////////////Implement Circuit Breaker Start///////////////////////////////////////////////////////////////////////////////////////////////// 
    
    
    
    function stopPoolContractInEmergencySituation() public onlyAdmin {
        
        require(stopContract == false , 'Contracted has been already stoped Once in Emergency Situation') ;
        
        stopContract = true ;
        
    }
    
    

    
       ///////////////////////////////////////////////////////////////////Implement Circuit Breaker End///////////////////////////////////////////////////////////////////////////////////////////////// 
   
 
}









